import 'package:drift/drift.dart';

import 'medications_table.dart';

@DataClassName('MedicationIntakeRow')
class MedicationIntakes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get medicationId => integer()
      .references(Medications, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get takenAt => dateTime()();
  BoolColumn get skipped =>
      boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  TextColumn get householdId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
