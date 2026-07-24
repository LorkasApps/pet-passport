import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/pending_ops_table.dart';

part 'pending_ops_dao.g.dart';

/// Thin access layer over the pending_ops table.
@DriftAccessor(tables: [PendingOps])
class PendingOpsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingOpsDaoMixin {
  PendingOpsDao(super.db);

  Future<int> enqueue(PendingOpsCompanion op) => into(pendingOps).insert(op);

  /// FIFO drain window. Caller filters retriable ops (backoff) via
  /// `attempts` / `lastAttemptAt` after fetching — keeping this method
  /// dumb makes debugging with a plain "give me the head" call trivial.
  Future<List<PendingOpRow>> head({int limit = 20}) {
    return (select(pendingOps)
          ..orderBy([(o) => OrderingTerm.asc(o.id)])
          ..limit(limit))
        .get();
  }

  Future<int> count() async {
    final row = await (selectOnly(pendingOps)
          ..addColumns([pendingOps.id.count()]))
        .getSingle();
    return row.read(pendingOps.id.count()) ?? 0;
  }

  Future<int> markSuccess(int id) {
    return (delete(pendingOps)..where((o) => o.id.equals(id))).go();
  }

  Future<int> markFailure(int id, String error, DateTime at) {
    return (update(pendingOps)..where((o) => o.id.equals(id))).write(
      PendingOpsCompanion(
        attempts: const Value.absent(),
        lastAttemptAt: Value(at),
        lastError: Value(error),
      ),
    );
  }

  /// Atomic attempt-count bump — separate from markFailure so the
  /// counter increments even if error message logging fails to serialise.
  Future<int> incrementAttempts(int id) {
    return customUpdate(
      'UPDATE pending_ops SET attempts = attempts + 1 WHERE id = ?',
      variables: [Variable<int>(id)],
      updates: {pendingOps},
    );
  }

  /// Re-arm every parked op for another drain pass: zero out
  /// `attempts` (so backoff bypasses), clear `last_error`, forget the
  /// last attempt timestamp. Triggered by the manual "sync now" action
  /// in Settings, and by any recovery flow that wants to break out of
  /// the terminal-error park.
  Future<int> resetAllForRetry() {
    return customUpdate(
      'UPDATE pending_ops '
      'SET attempts = 0, last_error = NULL, last_attempt_at = NULL',
      updates: {pendingOps},
    );
  }

  Stream<int> watchCount() {
    final q = selectOnly(pendingOps)..addColumns([pendingOps.id.count()]);
    return q.watchSingle().map((r) => r.read(pendingOps.id.count()) ?? 0);
  }

  /// Most recent `last_error` across the outbox — the message the
  /// sync-status UI surfaces so the user can see WHY nothing's
  /// draining. Null when no op has an error attached.
  Stream<String?> watchLastError() {
    return (select(pendingOps)
          ..where((o) => o.lastError.isNotNull())
          ..orderBy([(o) => OrderingTerm.desc(o.lastAttemptAt)])
          ..limit(1))
        .watchSingleOrNull()
        .map((r) => r?.lastError);
  }
}
