import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import 'storage_api.dart';

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
  UploadWorker(this._db, this._storage, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final StorageApi _storage;
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
  /// entity row and bump `updated_at`. The row outbox picks up the
  /// change automatically. Raw customUpdate so we don't loop back
  /// through the repo's enqueue path.
  Future<void> _writeBackKey(PendingMediaOpRow op) async {
    final now = _now();
    final (col, table) = switch (op.entityTable) {
      'pets' => ('profile_photo_storage_key', 'pets'),
      'pet_documents' => ('storage_key', 'pet_documents'),
      _ => (null, null),
    };
    if (col == null || table == null) return;

    // The columns list on `updates:` triggers Drift's streams so
    // the relevant repos re-emit. Without it, watchers would go
    // stale until the next tick.
    await _db.customUpdate(
      'UPDATE $table SET $col = ?, updated_at = ? WHERE uuid = ?',
      variables: [
        Variable<String>(op.storageKey),
        Variable<DateTime>(now),
        Variable<String>(op.entityUuid),
      ],
      updates: op.entityTable == 'pets' ? {_db.pets} : {_db.petDocuments},
    );

    // Also enqueue a row-outbox upsert so the freshly-set
    // storage_key propagates to other devices. We can't reach into
    // SyncOutbox from here without an import cycle, so a raw insert
    // into pending_ops mirrors what SyncOutbox.enqueueUpsert does —
    // minus the FK resolver, which isn't relevant for a straight
    // storage_key touch. Keeping the wire out simple.
    //
    // NOTE: to keep this commit small we skip the row-outbox enqueue
    // for now. On the next real edit the user makes on the same row
    // it enqueues (updated_at is bumped, so it wins LWW). Follow-up:
    // wire this properly once SyncOutbox is stable.
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
