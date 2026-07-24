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
  /// Cloud Storage object key for the file, filled once the media
  /// outbox has uploaded it. Rows without a `storage_key` haven't
  /// been sent yet; `file_path` remains a device-local hint that
  /// never gets synced.
  TextColumn get storageKey => text().nullable()();
  TextColumn get mimeType => text().withLength(min: 1, max: 128)();
  TextColumn get originalFilename => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get householdId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
