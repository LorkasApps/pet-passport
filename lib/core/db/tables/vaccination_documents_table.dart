import 'package:drift/drift.dart';

import 'vaccinations_table.dart';

@DataClassName('VaccinationDocumentRow')
class VaccinationDocuments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get vaccinationId => integer()
      .references(Vaccinations, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  TextColumn get filePath => text()();
  TextColumn get mimeType => text()();
  TextColumn get originalFilename => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
