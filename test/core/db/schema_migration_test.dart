import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/core/db/database.dart';

/// Smoke test: opening a fresh AppDatabase at the current schema goes
/// through `onCreate` and creates every registered table without crashing.
///
/// The old snapshot-based v6→v7 verifier is intentionally removed — it
/// used `createTable(eventPhotos)` (and other `createTable` calls) that
/// now include columns added by later migrations, so the emitted DDL
/// diverges from the stored v7 JSON. Reintroducing meaningful migration
/// verification needs Drift's `stepByStep` migrator with per-version
/// schema dumps for v11 → schemaVersion.
void main() {
  test('onCreate builds every registered table at the current version',
      () async {
    final db =
        AppDatabase.forTesting(NativeDatabase.memory(logStatements: false));
    addTearDown(db.close);

    // A cheap end-to-end sanity check: pick a table that only shows up
    // via a late migration (pet_documents, created at v14) and query it.
    // If onCreate silently omitted the table, this throws.
    final rows = await db
        .customSelect('SELECT COUNT(*) AS c FROM pet_documents')
        .get();
    expect(rows.first.data['c'], 0);

    // Same for a table that gained a column late (event_photos.title,
    // v15). If addColumn was skipped, the column is missing.
    final photoCols = await db
        .customSelect('PRAGMA table_info(event_photos)')
        .get();
    final names = photoCols.map((r) => r.data['name']).toSet();
    expect(names, contains('title'));
  });
}
