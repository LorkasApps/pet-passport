import 'package:drift/drift.dart';

import 'medications_table.dart';

@DataClassName('MedicationReminderRow')
class MedicationReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicationId => integer()
      .references(Medications, #id, onDelete: KeyAction.cascade)();
  IntColumn get offsetMinutes => integer()();
}
