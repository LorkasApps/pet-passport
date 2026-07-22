import 'package:drift/drift.dart';

import 'appointments_table.dart';

@DataClassName('AppointmentExceptionRow')
class AppointmentExceptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get appointmentId => integer()
      .references(Appointments, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get occurrenceStart => dateTime()();
  BoolColumn get isCancelled =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get overrideStartsAt => dateTime().nullable()();
}
