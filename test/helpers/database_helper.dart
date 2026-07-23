import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/core/db/database.dart';

// A handful of tests intentionally spin up a second AppDatabase inside a
// test body (round-trip export→import; some events tests) on top of the
// one their `setUp` created. Drift then warns about "multiple databases"
// even though each uses its own in-memory executor and there is no shared
// state. Silence the warning globally for the test process — prod code
// still uses a single AppDatabase via `databaseProvider`.
final _silence = () {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return true;
}();

/// Returns a fresh in-memory [AppDatabase] for unit tests. The database is
/// automatically closed at test tear-down so consecutive `setUp` calls do
/// not leak instances.
AppDatabase newInMemoryDatabase() {
  // Reference the initializer so it runs on first call.
  assert(_silence);
  final executor = LazyDatabase(() async => NativeDatabase.memory());
  final db = AppDatabase.forTesting(executor);
  addTearDown(db.close);
  return db;
}
