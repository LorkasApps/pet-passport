import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
import '../database.dart';
import '../tables/event_photos_table.dart';

part 'event_photos_dao.g.dart';

@DriftAccessor(tables: [EventPhotos])
class EventPhotosDao extends DatabaseAccessor<AppDatabase>
    with _$EventPhotosDaoMixin {
  EventPhotosDao(super.db);

  Stream<List<EventPhotoRow>> watchForEvent(int eventId) {
    return (select(eventPhotos)
          ..where((p) => p.eventId.equals(eventId) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Future<EventPhotoRow?> getByUuid(String uuid) {
    return (select(eventPhotos)
          ..where((p) => p.uuid.equals(uuid) & p.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<EventPhotoRow?> getByUuidIncludingDeleted(String uuid) {
    return (select(eventPhotos)..where((p) => p.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<int> insertPhoto(EventPhotosCompanion companion) {
    return into(eventPhotos).insert(companion);
  }

  Future<bool> updatePhoto(EventPhotoRow row) {
    return update(eventPhotos).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(eventPhotos)..where((p) => p.uuid.equals(uuid)))
        .write(EventPhotosCompanion(
      deletedAt: Value(deletedAt),
      updatedAt: Value(deletedAt),
      updatedByUserId: Value(currentUserId()),
    ));
  }

  Future<int> deleteAllForEvent(int eventId) {
    return (delete(eventPhotos)..where((p) => p.eventId.equals(eventId))).go();
  }

  Future<int> countForEvent(int eventId) async {
    final row = await (selectOnly(eventPhotos)
          ..addColumns([eventPhotos.id.count()])
          ..where(eventPhotos.eventId.equals(eventId) &
              eventPhotos.deletedAt.isNull()))
        .getSingle();
    return row.read(eventPhotos.id.count()) ?? 0;
  }
}
