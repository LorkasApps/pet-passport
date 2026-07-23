import 'package:drift/drift.dart';

import 'pets_table.dart';
import 'vets_table.dart';

@DataClassName('VaccinationRow')
class Vaccinations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get petId =>
      integer().references(Pets, #id, onDelete: KeyAction.cascade)();
  TextColumn get vaccineName => text().withLength(min: 1, max: 200)();
  DateTimeColumn get administeredAt => dateTime()();
  DateTimeColumn get nextDueAt => dateTime().nullable()();
  IntColumn get vetId => integer()
      .nullable()
      .references(Vets, #id, onDelete: KeyAction.setNull)();
  TextColumn get batchNumber => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get householdId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
