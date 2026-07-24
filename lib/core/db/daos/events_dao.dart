import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
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
    final query = select(events)..where((e) => e.petId.equals(petId) & e.deletedAt.isNull());
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
    final query = select(events)..where((e) => e.deletedAt.isNull());
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
    return (select(events)..where((e) => e.uuid.equals(uuid) & e.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<EventRow?> getByUuidIncludingDeleted(String uuid) {
    return (select(events)..where((e) => e.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  /// Local-id lookup used by the sync-outbox FK resolver to translate
  /// a child row's parent int-FK into the parent's uuid.
  Future<EventRow?> getById(int id) {
    return (select(events)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<EventRow?> watchByUuid(String uuid) {
    return (select(events)..where((e) => e.uuid.equals(uuid) & e.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<int> insertEvent(EventsCompanion companion) {
    return into(events).insert(companion);
  }

  Future<bool> updateEvent(EventRow row) {
    return update(events).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(events)..where((e) => e.uuid.equals(uuid)))
        .write(EventsCompanion(
          deletedAt: Value(deletedAt),
          updatedAt: Value(deletedAt),
          updatedByUserId: Value(currentUserId()),
        ));
  }

  // ── Tags ──────────────────────────────────────────────────────────────
  Stream<List<EventTagRow>> watchAllTags() {
    return (select(eventTags)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.label)]))
        .watch();
  }

  Future<EventTagRow?> getTagByUuid(String uuid) {
    return (select(eventTags)..where((t) => t.uuid.equals(uuid) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<EventTagRow?> getTagByLabel(String label) {
    return (select(eventTags)..where((t) => t.label.equals(label) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<int> insertTag(EventTagsCompanion companion) {
    return into(eventTags).insert(companion);
  }

  Future<int> softDeleteTagByUuid(String uuid, DateTime deletedAt) {
    return (update(eventTags)..where((t) => t.uuid.equals(uuid)))
        .write(EventTagsCompanion(
          deletedAt: Value(deletedAt),
          updatedByUserId: Value(currentUserId()),
        ));
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
          ..where((p) => p.eventId.equals(eventId) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Future<int> insertPhoto(EventPhotosCompanion companion) {
    return into(eventPhotos).insert(companion);
  }

  Future<EventPhotoRow?> getPhotoByUuid(String uuid) {
    return (select(eventPhotos)..where((p) => p.uuid.equals(uuid) & p.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getPhotoByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<EventPhotoRow?> getPhotoByUuidIncludingDeleted(String uuid) {
    return (select(eventPhotos)..where((p) => p.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<int> softDeletePhotoByUuid(String uuid, DateTime deletedAt) {
    return (update(eventPhotos)..where((p) => p.uuid.equals(uuid)))
        .write(EventPhotosCompanion(
          deletedAt: Value(deletedAt),
          updatedAt: Value(deletedAt),
          updatedByUserId: Value(currentUserId()),
        ));
  }
}
