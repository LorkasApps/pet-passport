import 'package:drift/drift.dart';

import '../../../features/medications/domain/medication_enums.dart';
import 'pets_table.dart';
import 'vets_table.dart';

@DataClassName('MedicationRow')
class Medications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get petId =>
      integer().references(Pets, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  RealColumn get dosageAmount => real().withDefault(const Constant(0))();
  TextColumn get dosageUnit =>
      text().withLength(min: 0, max: 32).withDefault(const Constant(''))();
  IntColumn get freqType => intEnum<FreqType>()
      .withDefault(const Constant(0))(); // FreqType.daily
  IntColumn get freqInterval =>
      integer().withDefault(const Constant(1))();
  IntColumn get freqWeekdays =>
      integer().withDefault(const Constant(0))(); // bitmask, Mon=1
  TextColumn get timesOfDayJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  IntColumn get prescribedByVetId => integer()
      .nullable()
      .references(Vets, #id, onDelete: KeyAction.setNull)();
  BoolColumn get withFood =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
