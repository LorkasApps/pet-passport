import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/pending_media_ops_table.dart';

part 'pending_media_ops_dao.g.dart';

/// Thin access layer over the pending_media_ops table. Mirrors the
/// PendingOpsDao pattern so the upload worker's drain loop looks
/// familiar next to the push worker.
@DriftAccessor(tables: [PendingMediaOps])
class PendingMediaOpsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingMediaOpsDaoMixin {
  PendingMediaOpsDao(super.db);

  Future<int> enqueue(PendingMediaOpsCompanion op) =>
      into(pendingMediaOps).insert(op);

  Future<List<PendingMediaOpRow>> head({int limit = 10}) {
    return (select(pendingMediaOps)
          ..orderBy([(o) => OrderingTerm.asc(o.id)])
          ..limit(limit))
        .get();
  }

  Future<int> count() async {
    final row = await (selectOnly(pendingMediaOps)
          ..addColumns([pendingMediaOps.id.count()]))
        .getSingle();
    return row.read(pendingMediaOps.id.count()) ?? 0;
  }

  Stream<int> watchCount() {
    final q = selectOnly(pendingMediaOps)
      ..addColumns([pendingMediaOps.id.count()]);
    return q.watchSingle().map((r) => r.read(pendingMediaOps.id.count()) ?? 0);
  }

  Future<int> markSuccess(int id) {
    return (delete(pendingMediaOps)..where((o) => o.id.equals(id))).go();
  }

  Future<int> markFailure(int id, String error, DateTime at) {
    return (update(pendingMediaOps)..where((o) => o.id.equals(id))).write(
      PendingMediaOpsCompanion(
        lastAttemptAt: Value(at),
        lastError: Value(error),
      ),
    );
  }

  Future<int> incrementAttempts(int id) {
    return customUpdate(
      'UPDATE pending_media_ops SET attempts = attempts + 1 WHERE id = ?',
      variables: [Variable<int>(id)],
      updates: {pendingMediaOps},
    );
  }

  /// Same escape hatch [PendingOpsDao.resetAllForRetry] provides —
  /// wired into the "Sync now" action so a terminal upload gets one
  /// more chance after the user corrects whatever broke it.
  Future<int> resetAllForRetry() {
    return customUpdate(
      'UPDATE pending_media_ops '
      'SET attempts = 0, last_error = NULL, last_attempt_at = NULL',
      updates: {pendingMediaOps},
    );
  }
}
