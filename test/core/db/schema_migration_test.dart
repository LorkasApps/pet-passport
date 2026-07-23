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

  test('v16 sync columns present on every top-level table', () async {
    // Guards the M2 schema promise: every entity that participates in
    // cloud sync exposes the household_id / updated_by_user_id /
    // deleted_at triplet. A future refactor that drops any of these
    // columns from a table trips this test — pick the removal
    // deliberately, don't slip it in.
    final db =
        AppDatabase.forTesting(NativeDatabase.memory(logStatements: false));
    addTearDown(db.close);

    const topLevelTables = [
      'pets',
      'vets',
      'contacts',
      'appointments',
      'medications',
      'medication_intakes',
      'foods',
      'vaccinations',
      'insurances',
      'events',
      'event_tags',
      'pet_weights',
      'pet_documents',
    ];
    for (final table in topLevelTables) {
      final cols =
          await db.customSelect('PRAGMA table_info($table)').get();
      final names = cols.map((r) => r.data['name']).toSet();
      expect(names, containsAll(<String>['household_id', 'updated_by_user_id', 'deleted_at']),
          reason: 'table `$table` is missing one of the M2 sync columns');
    }
  });
}
