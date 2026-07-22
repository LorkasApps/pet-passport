import 'package:drift/drift.dart';

import 'appointments_table.dart';

@DataClassName('AppointmentReminderRow')
class AppointmentReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get appointmentId => integer()
      .references(Appointments, #id, onDelete: KeyAction.cascade)();
  IntColumn get offsetMinutes => integer()();
}
