import 'package:drift/drift.dart';

/// Per-table pull cursor. `last_pulled_seq` is the highest cloud-side
/// `pulled_seq` (a server-monotonic bigserial) this device has ever
/// pulled for the given table; a fresh pull asks Supabase for rows
/// strictly newer than this seq.
///
/// The seq column replaced the earlier `last_pulled_at` datetime
/// cursor to close the cursor-race window: with client-writable
/// `updated_at`, cross-device edits with skewed clocks could produce
/// rows whose updated_at is earlier than a cursor already advanced
/// past — those rows would be skipped forever. Server-side
/// nextval-based `pulled_seq` is monotonic across writes regardless
/// of client clock, so the cursor's "everything up to N seen" claim
/// is honest.
///
/// LWW conflict resolution still uses `updated_at`. Only the pull
/// cursor axis moved.
///
/// Never itself syncs. Local-only bookkeeping.
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  // Named `entity` (not `tableName`) because `tableName` clashes with
  // Drift's built-in `Table.tableName` accessor. Stored as `entity` in
  // SQL — old logs may still refer to "sync_cursors.table_name" if you
  // find them; they mean this column.
  TextColumn get entity => text()();
  IntColumn get lastPulledSeq => integer()();

  @override
  Set<Column> get primaryKey => {entity};
}
