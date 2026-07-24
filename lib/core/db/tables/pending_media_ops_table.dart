import 'package:drift/drift.dart';

/// Media outbox — one row per pending upload or delete against
/// Supabase Storage. Parallel to `pending_ops` (which handles row
/// upserts on Postgres), separated because media transport is
/// binary and slow: we don't want a stuck 20 MB upload to block
/// row sync.
///
/// Local-only. Never itself syncs; the upload worker writes the
/// resulting `storage_key` back into the owning entity row, which
/// then rides through the row outbox on its own.
@DataClassName('PendingMediaOpRow')
class PendingMediaOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get opType => text()(); // 'upload' | 'delete'
  TextColumn get entityTable => text()(); // e.g. 'pets', 'pet_documents'
  TextColumn get entityUuid => text()();
  /// Absolute local path of the source file for uploads; null for
  /// deletes (the storage key alone is enough).
  TextColumn get localPath => text().nullable()();
  /// Cloud key. For uploads this is where we put it; for deletes
  /// this is what we're removing.
  TextColumn get storageKey => text()();
  /// Whitelisted at the storage bucket level; carrying it here lets
  /// the upload set the right Content-Type header without touching
  /// the file system twice.
  TextColumn get mimeType => text().nullable()();
  DateTimeColumn get queuedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
}
