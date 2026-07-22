import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/core/db/database.dart';

import 'generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates cleanly from v6 to v7', () async {
    final connection = await verifier.startAt(6);
    final db = AppDatabase.forTesting(connection.executor);
    await verifier.migrateAndValidate(db, 7);
    await db.close();
  });
}
