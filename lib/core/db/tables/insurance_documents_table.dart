import 'package:drift/drift.dart';

import 'insurances_table.dart';

@DataClassName('InsuranceDocumentRow')
class InsuranceDocuments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get insuranceId => integer()
      .references(Insurances, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  TextColumn get filePath => text()(); // relative to app documents dir
  TextColumn get mimeType => text()();
  TextColumn get originalFilename => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get householdId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get storageKey => text().nullable()();
}
