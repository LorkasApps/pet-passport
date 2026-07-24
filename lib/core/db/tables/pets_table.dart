import 'package:drift/drift.dart';

import '../../../features/pets/domain/pet_enums.dart';

@DataClassName('PetRow')
class Pets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get species => intEnum<Species>()();
  TextColumn get breed => text().nullable()();
  IntColumn get sex => intEnum<Sex>()();
  BoolColumn get isNeutered => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get chipNumber => text().nullable()();
  TextColumn get tassoNumber => text().nullable()();
  TextColumn get vaccinationPassportNumber => text().nullable()();
  TextColumn get profilePhotoPath => text().nullable()();
  /// Cloud Storage object key for the profile photo, filled once the
  /// media outbox has uploaded the local file. Rows without a
  /// `storage_key` are still local-only from the media perspective —
  /// `profilePhotoPath` is a device-local hint and never gets synced.
  TextColumn get profilePhotoStorageKey => text().nullable()();
  TextColumn get allergies => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get householdId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();
}
