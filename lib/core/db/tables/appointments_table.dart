import 'package:drift/drift.dart';

import '../../../features/appointments/domain/appointment_enums.dart';
import 'contacts_table.dart';
import 'pets_table.dart';
import 'vets_table.dart';

@DataClassName('AppointmentRow')
class Appointments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get petId =>
      integer().references(Pets, #id, onDelete: KeyAction.cascade)();
  IntColumn get vetId => integer()
      .nullable()
      .references(Vets, #id, onDelete: KeyAction.setNull)();
  IntColumn get contactId => integer()
      .nullable()
      .references(Contacts, #id, onDelete: KeyAction.setNull)();
  IntColumn get type => intEnum<AppointmentType>()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  DateTimeColumn get startsAt => dateTime()();
  IntColumn get durationMinutes =>
      integer().withDefault(const Constant(60))();
  TextColumn get location => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get recurrenceFreq => intEnum<RecurrenceFreq>()
      .withDefault(const Constant(0))(); // RecurrenceFreq.none
  IntColumn get recurrenceInterval =>
      integer().withDefault(const Constant(1))();
  IntColumn get recurrenceWeekdays =>
      integer().withDefault(const Constant(0))(); // bitmask, Mon=1
  DateTimeColumn get recurrenceUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
