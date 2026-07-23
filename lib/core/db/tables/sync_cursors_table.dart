import 'package:drift/drift.dart';

/// Per-table pull cursor. `last_pulled_at` is the newest `updated_at`
/// this device has ever pulled for the given table; a fresh pull asks
/// Supabase for rows strictly newer than this stamp.
///
/// Never itself syncs. Local-only bookkeeping.
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  // Named `entity` (not `tableName`) because `tableName` clashes with
  // Drift's built-in `Table.tableName` accessor. Stored as `entity` in
  // SQL — old logs may still refer to "sync_cursors.table_name" if you
  // find them; they mean this column.
  TextColumn get entity => text()();
  DateTimeColumn get lastPulledAt => dateTime()();

  @override
  Set<Column> get primaryKey => {entity};
}
