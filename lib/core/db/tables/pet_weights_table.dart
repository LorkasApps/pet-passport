import 'package:drift/drift.dart';

import 'pets_table.dart';

@DataClassName('PetWeightRow')
class PetWeights extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get petId =>
      integer().references(Pets, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get measuredAt => dateTime()();
  RealColumn get weightKg => real()();
  TextColumn get note => text().nullable()();
  TextColumn get sourceEventUuid => text().nullable()();
  TextColumn get householdId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
