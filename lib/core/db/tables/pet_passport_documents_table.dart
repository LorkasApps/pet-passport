import 'package:drift/drift.dart';

import 'pets_table.dart';

@DataClassName('PetPassportDocumentRow')
class PetPassportDocuments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get petId =>
      integer().references(Pets, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  TextColumn get filePath => text()();
  TextColumn get mimeType => text().withLength(min: 1, max: 128)();
  TextColumn get originalFilename => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get householdId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get storageKey => text().nullable()();
}
