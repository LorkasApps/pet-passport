import 'package:drift/drift.dart';

import '../../../features/protocol/domain/event_enums.dart';
import '../database.dart';
import '../tables/event_photos_table.dart';
import '../tables/event_tag_links_table.dart';
import '../tables/event_tags_table.dart';
import '../tables/events_table.dart';

part 'events_dao.g.dart';

@DriftAccessor(tables: [Events, EventTags, EventTagLinks, EventPhotos])
class EventsDao extends DatabaseAccessor<AppDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  Stream<List<EventRow>> watchForPet(
    int petId, {
    EventType? typeFilter,
    DateTime? from,
    DateTime? to,
  }) {
    final query = select(events)..where((e) => e.petId.equals(petId));
    if (typeFilter != null) {
      query.where((e) => e.eventType.equalsValue(typeFilter));
    }
    if (from != null) {
      query.where((e) => e.occurredAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((e) => e.occurredAt.isSmallerOrEqualValue(to));
    }
    query.orderBy([(e) => OrderingTerm.desc(e.occurredAt)]);
    return query.watch();
  }

  /// Cross-pet stream, filtered by occurredAt window. Newest first.
  Stream<List<EventRow>> watchAllInRange({DateTime? from, DateTime? to}) {
    final query = select(events);
    if (from != null) {
      query.where((e) => e.occurredAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((e) => e.occurredAt.isSmallerOrEqualValue(to));
    }
    query.orderBy([(e) => OrderingTerm.desc(e.occurredAt)]);
    return query.watch();
  }

  Future<EventRow?> getByUuid(String uuid) {
    return (select(events)..where((e) => e.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Stream<EventRow?> watchByUuid(String uuid) {
    return (select(events)..where((e) => e.uuid.equals(uuid)))
        .watchSingleOrNull();
  }

  Future<int> insertEvent(EventsCompanion companion) {
    return into(events).insert(companion);
  }

  Future<bool> updateEvent(EventRow row) {
    return update(events).replace(row);
  }

  Future<int> deleteByUuid(String uuid) {
    return (delete(events)..where((e) => e.uuid.equals(uuid))).go();
  }

  // ── Tags ──────────────────────────────────────────────────────────────
  Stream<List<EventTagRow>> watchAllTags() {
    return (select(eventTags)..orderBy([(t) => OrderingTerm.asc(t.label)]))
        .watch();
  }

  Future<EventTagRow?> getTagByUuid(String uuid) {
    return (select(eventTags)..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<EventTagRow?> getTagByLabel(String label) {
    return (select(eventTags)..where((t) => t.label.equals(label)))
        .getSingleOrNull();
  }

  Future<int> insertTag(EventTagsCompanion companion) {
    return into(eventTags).insert(companion);
  }

  Future<int> deleteTagByUuid(String uuid) {
    return (delete(eventTags)..where((t) => t.uuid.equals(uuid))).go();
  }

  Future<void> linkTagToEvent(int eventId, int tagId) async {
    await into(eventTagLinks).insertOnConflictUpdate(
      EventTagLinksCompanion.insert(eventId: eventId, tagId: tagId),
    );
  }

  Future<int> unlinkTagFromEvent(int eventId, int tagId) {
    return (delete(eventTagLinks)
          ..where((l) => l.eventId.equals(eventId) & l.tagId.equals(tagId)))
        .go();
  }

  Stream<List<EventTagRow>> watchTagsForEvent(int eventId) {
    final query = select(eventTags).join([
      innerJoin(
        eventTagLinks,
        eventTagLinks.tagId.equalsExp(eventTags.id),
      ),
    ])
      ..where(eventTagLinks.eventId.equals(eventId))
      ..orderBy([OrderingTerm.asc(eventTags.label)]);
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(eventTags)).toList(),
        );
  }

  // ── Photos ────────────────────────────────────────────────────────────
  Stream<List<EventPhotoRow>> watchPhotosForEvent(int eventId) {
    return (select(eventPhotos)
          ..where((p) => p.eventId.equals(eventId))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Future<int> insertPhoto(EventPhotosCompanion companion) {
    return into(eventPhotos).insert(companion);
  }

  Future<EventPhotoRow?> getPhotoByUuid(String uuid) {
    return (select(eventPhotos)..where((p) => p.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<int> deletePhotoByUuid(String uuid) {
    return (delete(eventPhotos)..where((p) => p.uuid.equals(uuid))).go();
  }
}
