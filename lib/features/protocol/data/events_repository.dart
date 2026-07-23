import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/events_dao.dart';
import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/media/media_service.dart';
import '../../../core/supabase/current_user.dart';
import '../domain/event.dart';
import '../domain/event_enums.dart';
import '../domain/event_payload.dart';
import '../domain/event_photo.dart';
import '../domain/event_tag.dart';

class EventsRepository {
  EventsRepository(
    this._db,
    this._eventsDao,
    this._petsDao,
    this._media, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final EventsDao _eventsDao;
  final PetsDao _petsDao;
  final MediaService _media;
  final Uuid _uuid;

  Stream<List<Event>> watchForPetUuid(
    String petUuid, {
    EventType? typeFilter,
    DateTime? from,
    DateTime? to,
  }) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _eventsDao
        .watchForPet(pet.id, typeFilter: typeFilter, from: from, to: to)
        .asyncMap((rows) async {
      final result = <Event>[];
      for (final row in rows) {
        result.add(await _toDomain(row, petUuid));
      }
      return result;
    });
  }

  Stream<Event?> watchByUuid(String uuid, String petUuid) {
    return _eventsDao.watchByUuid(uuid).asyncMap((row) async {
      if (row == null) return null;
      return _toDomain(row, petUuid);
    });
  }

  Future<Event?> getByUuid(String uuid, String petUuid) async {
    final row = await _eventsDao.getByUuid(uuid);
    if (row == null) return null;
    return _toDomain(row, petUuid);
  }

  Future<String> createEvent({
    required String petUuid,
    required EventType type,
    required DateTime occurredAt,
    String? title,
    String? note,
    required EventPayload payload,
  }) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) throw StateError('Pet not found: $petUuid');
    final eventUuid = _uuid.v4();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _eventsDao.insertEvent(EventsCompanion.insert(
        uuid: eventUuid,
        petId: pet.id,
        eventType: type,
        occurredAt: occurredAt,
        title: Value(title),
        note: Value(note),
        payloadJson: Value(_encodePayload(payload)),
        createdAt: now,
        updatedAt: now,
        updatedByUserId: Value(currentUserId()),
      ));
      if (type == EventType.weight && payload is WeightPayload) {
        await _petsDao.insertWeight(PetWeightsCompanion.insert(
          petId: pet.id,
          measuredAt: occurredAt,
          weightKg: payload.weightKg,
          note: Value(note),
          sourceEventUuid: Value(eventUuid),
        ));
      }
    });
    return eventUuid;
  }

  Future<void> updateEvent({
    required String uuid,
    required EventType type,
    required DateTime occurredAt,
    String? title,
    String? note,
    required EventPayload payload,
  }) async {
    final existing = await _eventsDao.getByUuid(uuid);
    if (existing == null) throw StateError('Event not found: $uuid');
    await _db.transaction(() async {
      await _eventsDao.updateEvent(existing.copyWith(
        eventType: type,
        occurredAt: occurredAt,
        title: Value(title),
        note: Value(note),
        payloadJson: Value(_encodePayload(payload)),
        updatedAt: DateTime.now(),
        updatedByUserId: Value(currentUserId()),
      ));
      // Sync pet_weights row via source_event_uuid. If the event type
      // changed away from weight, drop the linked pet_weights row.
      final existingWeight = await (_db.select(_db.petWeights)
            ..where((w) => w.sourceEventUuid.equals(uuid)))
          .getSingleOrNull();
      if (type == EventType.weight && payload is WeightPayload) {
        if (existingWeight == null) {
          await _petsDao.insertWeight(PetWeightsCompanion.insert(
            petId: existing.petId,
            measuredAt: occurredAt,
            weightKg: payload.weightKg,
            note: Value(note),
            sourceEventUuid: Value(uuid),
            updatedByUserId: Value(currentUserId()),
          ));
        } else {
          await (_db.update(_db.petWeights)
                ..where((w) => w.id.equals(existingWeight.id)))
              .write(PetWeightsCompanion(
            measuredAt: Value(occurredAt),
            weightKg: Value(payload.weightKg),
            note: Value(note),
            updatedByUserId: Value(currentUserId()),
          ));
        }
      } else if (existingWeight != null) {
        await (_db.delete(_db.petWeights)
              ..where((w) => w.id.equals(existingWeight.id)))
            .go();
      }
    });
  }

  Future<void> deleteByUuid(String uuid) async {
    await _db.transaction(() async {
      // Remove linked pet_weights row (no FK, so manual).
      await (_db.delete(_db.petWeights)
            ..where((w) => w.sourceEventUuid.equals(uuid)))
          .go();
      // Photos on disk need explicit cleanup — DB cascade only removes
      // rows.
      final row = await _eventsDao.getByUuid(uuid);
      if (row != null) {
        final photos = await _eventsDao.watchPhotosForEvent(row.id).first;
        for (final p in photos) {
          await _media.deleteFile(p.filePath);
        }
      }
      await _eventsDao.deleteByUuid(uuid);
    });
  }

  // ── Photos ──────────────────────────────────────────────────────────
  Future<String> attachPhoto({
    required String eventUuid,
    required File source,
    required String mimeType,
    int? sizeBytes,
  }) async {
    final row = await _eventsDao.getByUuid(eventUuid);
    if (row == null) throw StateError('Event not found: $eventUuid');
    final photoUuid = _uuid.v4();
    final relative = await _media.saveEventPhoto(
      eventUuid: eventUuid,
      photoUuid: photoUuid,
      source: source,
    );
    await _eventsDao.insertPhoto(EventPhotosCompanion.insert(
      uuid: photoUuid,
      eventId: row.id,
      filePath: relative,
      mimeType: mimeType,
      sizeBytes: Value(sizeBytes),
      createdAt: DateTime.now(),
    ));
    return photoUuid;
  }

  Future<void> removePhoto(String photoUuid) async {
    final row = await _eventsDao.getPhotoByUuid(photoUuid);
    if (row == null) return;
    await _eventsDao.deletePhotoByUuid(photoUuid);
    await _media.deleteFile(row.filePath);
  }

  /// User-visible rename — only touches the [title] column, so the
  /// on-disk file, its extension and original filename all stay put.
  /// Passing an empty string (or null) clears the title back to unset.
  Future<void> renamePhoto(String photoUuid, String? title) async {
    final trimmed = title?.trim();
    await (_db.update(_db.eventPhotos)
          ..where((p) => p.uuid.equals(photoUuid)))
        .write(EventPhotosCompanion(
      title: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
    ));
  }

  // ── Tags ────────────────────────────────────────────────────────────
  Stream<List<EventTag>> watchAllTags() {
    return _eventsDao.watchAllTags().map(
          (rows) => rows.map(_tagToDomain).toList(growable: false),
        );
  }

  Future<String> createTag({required String label, int? color}) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) throw ArgumentError('label must not be empty');
    // Reuse existing tag with same label if present.
    final existing = await _eventsDao.getTagByLabel(trimmed);
    if (existing != null) return existing.uuid;
    final tagUuid = _uuid.v4();
    await _eventsDao.insertTag(EventTagsCompanion.insert(
      uuid: tagUuid,
      label: trimmed,
      color: Value(color),
      createdAt: DateTime.now(),
      updatedByUserId: Value(currentUserId()),
    ));
    return tagUuid;
  }

  Future<void> assignTag({
    required String eventUuid,
    required String tagUuid,
  }) async {
    final event = await _eventsDao.getByUuid(eventUuid);
    final tag = await _eventsDao.getTagByUuid(tagUuid);
    if (event == null || tag == null) return;
    await _eventsDao.linkTagToEvent(event.id, tag.id);
  }

  Future<void> unassignTag({
    required String eventUuid,
    required String tagUuid,
  }) async {
    final event = await _eventsDao.getByUuid(eventUuid);
    final tag = await _eventsDao.getTagByUuid(tagUuid);
    if (event == null || tag == null) return;
    await _eventsDao.unlinkTagFromEvent(event.id, tag.id);
  }

  Future<void> deleteTag(String tagUuid) async {
    await _eventsDao.deleteTagByUuid(tagUuid);
  }

  // ── Mapping ─────────────────────────────────────────────────────────
  Future<Event> _toDomain(EventRow row, String petUuid) async {
    final payload =
        _decodePayload(row.eventType, row.payloadJson) ??
            EventPayload.empty(row.eventType);
    final tagRows = await _eventsDao.watchTagsForEvent(row.id).first;
    final photoRows = await _eventsDao.watchPhotosForEvent(row.id).first;
    return Event(
      uuid: row.uuid,
      petUuid: petUuid,
      type: row.eventType,
      occurredAt: row.occurredAt,
      title: row.title,
      note: row.note,
      payload: payload,
      tags: tagRows.map(_tagToDomain).toList(growable: false),
      photos: photoRows
          .map((p) => EventPhoto(
                uuid: p.uuid,
                title: p.title,
                filePath: p.filePath,
                mimeType: p.mimeType,
                sizeBytes: p.sizeBytes,
                createdAt: p.createdAt,
              ))
          .toList(growable: false),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  EventTag _tagToDomain(EventTagRow row) => EventTag(
        uuid: row.uuid,
        label: row.label,
        color: row.color,
        createdAt: row.createdAt,
      );

  String? _encodePayload(EventPayload payload) {
    final map = payload.toJson();
    if (map.isEmpty) return null;
    return jsonEncode(map);
  }

  EventPayload? _decodePayload(EventType type, String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      return EventPayload.fromJson(type, decoded);
    } catch (_) {
      return null;
    }
  }
}
