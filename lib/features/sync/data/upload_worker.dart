import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import 'storage_api.dart';
import 'sync_outbox.dart';

/// Media outbox drain loop. Mirrors [PushWorker]'s shape:
/// FIFO reads, per-op retry with backoff, single-flight.
///
/// After a successful UPLOAD the worker writes the resulting
/// storage_key back into the owning entity row via a raw UPDATE
/// (bypasses the repo so this write doesn't re-enqueue in the
/// media outbox) and bumps `updated_at` so the row outbox picks up
/// the change and pushes storage_key through row-sync to other
/// devices.
///
/// DELETE ops just call `StorageApi.deleteObject`; the row-side
/// tombstone is handled independently by whatever soft-deleted the
/// owning row.
class UploadWorker {
  UploadWorker(
    this._db,
    this._storage, {
    this.syncOutbox,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final StorageApi _storage;

  /// Row outbox. When present the worker enqueues an upsert on the
  /// owning entity after writing back a fresh storage_key, so peers
  /// see the key immediately instead of only on the user's next edit.
  /// Null in tests that don't care about downstream row-sync.
  final SyncOutbox? syncOutbox;
  final DateTime Function() _now;

  static const bucket = 'media';

  static const _backoffs = <Duration>[
    Duration.zero,
    Duration(milliseconds: 500),
    Duration(seconds: 2),
    Duration(seconds: 8),
    Duration(seconds: 30),
  ];

  Future<UploadDrainResult>? _inflight;

  Future<UploadDrainResult> drainOnce({int batch = 10}) {
    return _inflight ??= _run(batch).whenComplete(() => _inflight = null);
  }

  Future<UploadDrainResult> _run(int batch) async {
    final ops = await _db.pendingMediaOpsDao.head(limit: batch);
    var sent = 0;
    var retried = 0;
    var terminal = 0;
    var skippedBackoff = 0;

    for (final op in ops) {
      if (!_eligible(op)) {
        skippedBackoff++;
        continue;
      }
      final outcome = await _handleOne(op);
      switch (outcome) {
        case _Outcome.wrote:
          sent++;
        case _Outcome.retried:
          retried++;
        case _Outcome.terminal:
          terminal++;
      }
    }
    return UploadDrainResult(
      inspected: ops.length,
      sent: sent,
      retried: retried,
      terminal: terminal,
      skippedBackoff: skippedBackoff,
    );
  }

  Future<_Outcome> _handleOne(PendingMediaOpRow op) async {
    try {
      if (op.opType == 'upload') {
        final path = op.localPath;
        if (path == null) {
          return await _park(op, 'upload op has no local_path');
        }
        final file = File(path);
        if (!await file.exists()) {
          return await _park(op, 'source file gone: $path');
        }
        final result = await _storage.uploadObject(
          bucket: bucket,
          key: op.storageKey,
          file: file,
          mimeType: op.mimeType,
        );
        return await _translate(op, result, () => _writeBackKey(op));
      }
      if (op.opType == 'delete') {
        final result = await _storage.deleteObject(
          bucket: bucket,
          key: op.storageKey,
        );
        return await _translate(op, result, () async {});
      }
      return await _park(op, 'unknown op_type: ${op.opType}');
    } catch (e) {
      return await _retry(op, 'threw: $e');
    }
  }

  /// After a successful upload, put the storage_key into the owning
  /// entity row and bump `updated_at`. Raw customUpdate so we don't
  /// loop back through the repo's own media-enqueue path. Then, if a
  /// [SyncOutbox] was injected, enqueue a row-outbox upsert so peers
  /// see the fresh storage_key immediately — otherwise the key waits
  /// for the user's next edit on the row before it propagates.
  Future<void> _writeBackKey(PendingMediaOpRow op) async {
    final spec = _keyColFor(op.entityTable);
    if (spec == null) return;

    final now = _now();
    await _db.customUpdate(
      // updates: on the correct TableInfo so Drift's stream watchers
      // re-emit; without it a UI bound to `watchByUuid` would keep
      // showing the pre-key snapshot until the next tick.
      'UPDATE ${spec.table} '
      'SET ${spec.storageKeyColumn} = ?, updated_at = ? '
      'WHERE uuid = ?',
      variables: [
        Variable<String>(op.storageKey),
        Variable<DateTime>(now),
        Variable<String>(op.entityUuid),
      ],
      updates: {spec.driftTable(_db)},
    );

    final outbox = syncOutbox;
    if (outbox == null) return;
    final payload = await spec.fetchPayload(_db, op.entityUuid);
    if (payload == null) return;
    final hid = payload['householdId'] as String?;
    if (hid == null) return;
    await outbox.enqueueUpsert(
      entityTable: op.entityTable,
      entityUuid: op.entityUuid,
      householdId: hid,
      payload: payload,
    );
  }

  _WriteBackSpec? _keyColFor(String entityTable) {
    switch (entityTable) {
      case 'pets':
        return _WriteBackSpec(
          table: 'pets',
          storageKeyColumn: 'profile_photo_storage_key',
          driftTable: (db) => db.pets,
          fetchPayload: (db, uuid) async =>
              (await db.petsDao.getByUuid(uuid))?.toJson(),
        );
      case 'pet_documents':
        return _WriteBackSpec(
          table: 'pet_documents',
          storageKeyColumn: 'storage_key',
          driftTable: (db) => db.petDocuments,
          fetchPayload: (db, uuid) async =>
              (await db.petDocumentsDao.getByUuidIncludingDeleted(uuid))
                  ?.toJson(),
        );
      case 'pet_passport_documents':
        return _WriteBackSpec(
          table: 'pet_passport_documents',
          storageKeyColumn: 'storage_key',
          driftTable: (db) => db.petPassportDocuments,
          fetchPayload: (db, uuid) async => (await db
                  .petPassportDocumentsDao
                  .getByUuidIncludingDeleted(uuid))
              ?.toJson(),
        );
      case 'event_photos':
        return _WriteBackSpec(
          table: 'event_photos',
          storageKeyColumn: 'storage_key',
          driftTable: (db) => db.eventPhotos,
          fetchPayload: (db, uuid) async =>
              (await db.eventPhotosDao.getByUuidIncludingDeleted(uuid))
                  ?.toJson(),
        );
      case 'food_photos':
        return _WriteBackSpec(
          table: 'food_photos',
          storageKeyColumn: 'storage_key',
          driftTable: (db) => db.foodPhotos,
          fetchPayload: (db, uuid) async =>
              (await db.foodPhotosDao.getByUuidIncludingDeleted(uuid))
                  ?.toJson(),
        );
      case 'insurance_documents':
        return _WriteBackSpec(
          table: 'insurance_documents',
          storageKeyColumn: 'storage_key',
          driftTable: (db) => db.insuranceDocuments,
          fetchPayload: (db, uuid) async => (await db
                  .insuranceDocumentsDao
                  .getByUuidIncludingDeleted(uuid))
              ?.toJson(),
        );
      case 'vaccination_documents':
        return _WriteBackSpec(
          table: 'vaccination_documents',
          storageKeyColumn: 'storage_key',
          driftTable: (db) => db.vaccinationDocuments,
          fetchPayload: (db, uuid) async => (await db
                  .vaccinationDocumentsDao
                  .getByUuidIncludingDeleted(uuid))
              ?.toJson(),
        );
    }
    return null;
  }

  Future<_Outcome> _translate(
    PendingMediaOpRow op,
    StorageResult result,
    Future<void> Function() onSuccess,
  ) async {
    switch (result) {
      case StorageOk():
        await onSuccess();
        await _db.pendingMediaOpsDao.markSuccess(op.id);
        return _Outcome.wrote;
      case StorageRetryable(:final reason):
        return await _retry(op, reason);
      case StorageTerminal(:final reason):
        return await _terminal(op, 'terminal: $reason');
    }
  }

  Future<_Outcome> _retry(PendingMediaOpRow op, String reason) async {
    await _db.pendingMediaOpsDao.incrementAttempts(op.id);
    await _db.pendingMediaOpsDao.markFailure(op.id, reason, _now());
    return _Outcome.retried;
  }

  Future<_Outcome> _terminal(PendingMediaOpRow op, String reason) async {
    await _db.pendingMediaOpsDao.incrementAttempts(op.id);
    await _db.pendingMediaOpsDao.markFailure(op.id, reason, _now());
    return _Outcome.terminal;
  }

  Future<_Outcome> _park(PendingMediaOpRow op, String reason) {
    // "Park" = terminal with attempts bumped so it stops retrying
    // until "Sync now" re-arms it. Same UX contract as PushWorker.
    return _terminal(op, 'terminal: $reason');
  }

  bool _eligible(PendingMediaOpRow op) {
    final wait = op.attempts < _backoffs.length
        ? _backoffs[op.attempts]
        : null;
    if (wait == null) return false;
    final last = op.lastAttemptAt;
    if (last == null) return true;
    return _now().difference(last) >= wait;
  }
}

class UploadDrainResult {
  const UploadDrainResult({
    required this.inspected,
    required this.sent,
    required this.retried,
    required this.terminal,
    required this.skippedBackoff,
  });
  final int inspected;
  final int sent;
  final int retried;
  final int terminal;
  final int skippedBackoff;
}

enum _Outcome { wrote, retried, terminal }

/// Per-table config for `_writeBackKey`: the SQL column that carries
/// the storage key, the Drift table used for stream invalidation,
/// and a fetcher that returns the row's JSON payload for the
/// row-outbox enqueue.
class _WriteBackSpec {
  const _WriteBackSpec({
    required this.table,
    required this.storageKeyColumn,
    required this.driftTable,
    required this.fetchPayload,
  });

  final String table;
  final String storageKeyColumn;
  final ResultSetImplementation<dynamic, dynamic> Function(AppDatabase db)
      driftTable;
  final Future<Map<String, dynamic>?> Function(AppDatabase db, String uuid)
      fetchPayload;
}
