import 'package:drift/drift.dart';

import 'pets_table.dart';

/// General-purpose document bucket per pet — vet findings, insurance
/// letters, anything that does not belong to a specific vaccination /
/// insurance / passport entry.
@DataClassName('PetDocumentRow')
class PetDocuments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get petId =>
      integer().references(Pets, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  TextColumn get filePath => text()();
  TextColumn get mimeType => text().withLength(min: 1, max: 128)();
  TextColumn get originalFilename => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
