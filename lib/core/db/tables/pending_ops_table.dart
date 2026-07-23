import 'package:drift/drift.dart';

/// Outbox for cloud-sync push. Every local write on a top-level entity
/// enqueues one row here; the sync engine drains the queue FIFO,
/// upserts to Supabase, and deletes the row on success.
///
/// Wholesale-replace semantics: `payload_json` carries the whole row
/// state at enqueue time. If a second write on the same uuid comes in
/// before the first drains, we insert a second op — the drain will
/// upsert both, and the second one's payload wins (its updated_at is
/// larger). Simpler than dedup + collapse and correct under LWW.
///
/// Never itself syncs. Local-only bookkeeping.
@DataClassName('PendingOpRow')
class PendingOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get opType => text()(); // 'upsert' | 'delete'
  TextColumn get entityTable => text()(); // e.g. 'pets', 'vets'
  TextColumn get entityUuid => text()();
  TextColumn get householdId => text().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get queuedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
}
