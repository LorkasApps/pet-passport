import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/daos/pending_ops_dao.dart';
import '../../../core/db/database.dart';

/// High-level façade for enqueuing cloud-sync operations. Repositories
/// call this after every write on a top-level entity; the push engine
/// (M3-03) drains the queue asynchronously.
///
/// Soft-delete note: because deleted rows carry `deleted_at != null`
/// and their fields are otherwise intact, we don't need a separate
/// `delete` op type — a soft-delete write is just an `upsert` whose
/// payload has the tombstone. The `op_type` column stays in the schema
/// as an escape hatch for future hard-delete semantics.
class SyncOutbox {
  SyncOutbox(this._dao);

  final PendingOpsDao _dao;

  Future<void> enqueueUpsert({
    required String entityTable,
    required String entityUuid,
    required String? householdId,
    required Map<String, dynamic> payload,
  }) async {
    await _dao.enqueue(PendingOpsCompanion.insert(
      opType: 'upsert',
      entityTable: entityTable,
      entityUuid: entityUuid,
      householdId: Value(householdId),
      payloadJson: jsonEncode(payload),
      queuedAt: DateTime.now(),
    ));
  }

  Future<int> pendingCount() => _dao.count();

  Stream<int> watchPendingCount() => _dao.watchCount();
}
