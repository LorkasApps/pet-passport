import 'package:drift/drift.dart';

import 'pets_table.dart';

@DataClassName('InsuranceRow')
class Insurances extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get petId =>
      integer().references(Pets, #id, onDelete: KeyAction.cascade)();
  TextColumn get provider => text().withLength(min: 1, max: 200)();
  TextColumn get policyNumber => text().nullable()();
  DateTimeColumn get contractStart => dateTime().nullable()();
  DateTimeColumn get contractEnd => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get householdId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
