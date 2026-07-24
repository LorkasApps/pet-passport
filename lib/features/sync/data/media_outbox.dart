import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

/// High-level façade over the media outbox. Repositories call this
/// once a file has been persisted locally so the upload worker can
/// pick it up. Mirrors [SyncOutbox] but for binary media.
///
/// Wire shape of the storage key the client passes in:
/// `household/{hid}/{entity_table}/{entity_uuid}[/profile].{ext}`.
/// The RLS policy on `storage.objects` gates on the second path
/// segment, so the layout has to start with `household/{hid}/`.
class MediaOutbox {
  MediaOutbox(this._db);

  final AppDatabase _db;

  Future<void> enqueueUpload({
    required String entityTable,
    required String entityUuid,
    required String localPath,
    required String storageKey,
    String? mimeType,
  }) async {
    await _db.pendingMediaOpsDao.enqueue(PendingMediaOpsCompanion.insert(
      opType: 'upload',
      entityTable: entityTable,
      entityUuid: entityUuid,
      localPath: Value(localPath),
      storageKey: storageKey,
      mimeType: Value(mimeType),
      queuedAt: DateTime.now(),
    ));
  }

  /// Enqueue a storage-side delete. `localPath` isn't needed —
  /// the upload worker just calls `StorageApi.deleteObject` with
  /// the given key. Used on soft-delete of the owning entity
  /// (after a grace period, so an in-flight pull on another device
  /// doesn't 404).
  Future<void> enqueueDelete({
    required String entityTable,
    required String entityUuid,
    required String storageKey,
  }) async {
    await _db.pendingMediaOpsDao.enqueue(PendingMediaOpsCompanion.insert(
      opType: 'delete',
      entityTable: entityTable,
      entityUuid: entityUuid,
      storageKey: storageKey,
      queuedAt: DateTime.now(),
    ));
  }

  Future<int> pendingCount() => _db.pendingMediaOpsDao.count();

  Stream<int> watchPendingCount() =>
      _db.pendingMediaOpsDao.watchCount();
}
