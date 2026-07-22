import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:pet_passport/core/db/database.dart';

/// Returns a fresh in-memory [AppDatabase] for unit tests.
AppDatabase newInMemoryDatabase() {
  final executor = LazyDatabase(() async => NativeDatabase.memory());
  return AppDatabase.forTesting(executor);
}
