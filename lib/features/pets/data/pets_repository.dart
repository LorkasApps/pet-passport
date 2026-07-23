import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/media/media_service.dart';
import '../../../core/supabase/current_user.dart';
import '../domain/pet.dart';
import '../domain/pet_enums.dart';
import '../domain/pet_passport_document.dart';

class PetsRepository {
  PetsRepository(this._dao, {this.media, Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final PetsDao _dao;
  final MediaService? media;
  final Uuid _uuid;

  Stream<List<Pet>> watchActivePets() {
    return _dao.watchActivePets().map(
          (rows) => rows.map(_toDomain).toList(growable: false),
        );
  }

  Stream<Pet?> watchByUuid(String uuid) {
    return _dao.watchByUuid(uuid).asyncMap((row) async {
      if (row == null) return null;
      final weights = await _dao.watchWeightsForPet(row.id).first;
      return _toDomain(row, weights: weights);
    });
  }

  Future<Pet?> getByUuid(String uuid) async {
    final row = await _dao.getByUuid(uuid);
    if (row == null) return null;
    return _toDomain(row);
  }

  Future<int> countActive() => _dao.countActive();

  /// Creates a new pet. Returns the assigned UUID.
  Future<String> createPet({
    required String name,
    required Species species,
    required Sex sex,
    bool isNeutered = false,
    String? breed,
    DateTime? dateOfBirth,
    String? color,
    String? markings,
    String? chipNumber,
    String? tassoNumber,
    DateTime? tassoRegisteredAt,
    String? vaccinationPassportNumber,
    String? profilePhotoPath,
    String? allergies,
    String? notes,
    String? householdId,
  }) async {
    final now = DateTime.now();
    final petUuid = _uuid.v4();
    await _dao.insertPet(
      PetsCompanion.insert(
        uuid: petUuid,
        name: name,
        species: species,
        sex: sex,
        isNeutered: Value(isNeutered),
        breed: Value(breed),
        dateOfBirth: Value(dateOfBirth),
        color: Value(color),
        markings: Value(markings),
        chipNumber: Value(chipNumber),
        tassoNumber: Value(tassoNumber),
        tassoRegisteredAt: Value(tassoRegisteredAt),
        vaccinationPassportNumber: Value(vaccinationPassportNumber),
        profilePhotoPath: Value(profilePhotoPath),
        allergies: Value(allergies),
        notes: Value(notes),
        createdAt: now,
        updatedAt: now,
        updatedByUserId: Value(currentUserId()),
        householdId: Value(householdId),
      ),
    );
    return petUuid;
  }

  Future<void> updatePet({
    required String uuid,
    required String name,
    required Species species,
    required Sex sex,
    bool isNeutered = false,
    String? breed,
    DateTime? dateOfBirth,
    String? color,
    String? markings,
    String? chipNumber,
    String? tassoNumber,
    DateTime? tassoRegisteredAt,
    String? vaccinationPassportNumber,
    String? profilePhotoPath,
    String? allergies,
    String? notes,
  }) async {
    final existing = await _dao.getByUuid(uuid);
    if (existing == null) {
      throw StateError('Pet with uuid=$uuid not found');
    }
    final updated = existing.copyWith(
      name: name,
      species: species,
      sex: sex,
      isNeutered: isNeutered,
      breed: Value(breed),
      dateOfBirth: Value(dateOfBirth),
      color: Value(color),
      markings: Value(markings),
      chipNumber: Value(chipNumber),
      tassoNumber: Value(tassoNumber),
      tassoRegisteredAt: Value(tassoRegisteredAt),
      vaccinationPassportNumber: Value(vaccinationPassportNumber),
      profilePhotoPath: Value(profilePhotoPath),
      allergies: Value(allergies),
      notes: Value(notes),
      updatedAt: DateTime.now(),
      updatedByUserId: Value(currentUserId()),
    );
    await _dao.updatePet(updated);
  }

  /// Update only the vaccination passport number without touching other
  /// pet fields.
  Future<void> updatePassportNumber({
    required String petUuid,
    String? number,
  }) async {
    final row = await _dao.getByUuid(petUuid);
    if (row == null) throw StateError('Pet with uuid=$petUuid not found');
    await _dao.updatePet(row.copyWith(
      vaccinationPassportNumber: Value(number),
      updatedAt: DateTime.now(),
      updatedByUserId: Value(currentUserId()),
    ));
  }

  Stream<List<PetPassportDocument>> watchPassportDocs(String petUuid) async* {
    final row = await _dao.getByUuid(petUuid);
    if (row == null) {
      yield const [];
      return;
    }
    yield* _dao.watchPassportDocsForPet(row.id).map(
          (rows) => rows.map(_toPassportDoc).toList(growable: false),
        );
  }

  Future<String> attachPassportDoc({
    required String petUuid,
    required File source,
    required String mimeType,
    String? originalFilename,
    int? sizeBytes,
  }) async {
    final m = media;
    if (m == null) {
      throw StateError('MediaService required to attach documents.');
    }
    final row = await _dao.getByUuid(petUuid);
    if (row == null) throw StateError('Pet with uuid=$petUuid not found');
    final docUuid = _uuid.v4();
    final relative = await m.savePassportDocument(
      petUuid: petUuid,
      docUuid: docUuid,
      source: source,
    );
    await _dao.insertPassportDoc(PetPassportDocumentsCompanion.insert(
      uuid: docUuid,
      petId: row.id,
      filePath: relative,
      mimeType: mimeType,
      originalFilename: Value(originalFilename),
      sizeBytes: Value(sizeBytes),
      createdAt: DateTime.now(),
    ));
    return docUuid;
  }

  Future<void> removePassportDoc(String docUuid) async {
    final row = await _dao.getPassportDocByUuid(docUuid);
    if (row == null) return;
    await media?.deleteFile(row.filePath);
    await _dao.deletePassportDocByUuid(docUuid);
  }

  /// Rename a passport document — only the [title] column changes; the
  /// underlying file and `original_filename` remain untouched. Passing
  /// an empty string clears the title.
  Future<void> renamePassportDoc(String docUuid, String? title) async {
    final trimmed = title?.trim();
    await _dao.renamePassportDoc(
      docUuid,
      trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
  }

  PetPassportDocument _toPassportDoc(PetPassportDocumentRow row) {
    return PetPassportDocument(
      uuid: row.uuid,
      title: row.title,
      filePath: row.filePath,
      mimeType: row.mimeType,
      originalFilename: row.originalFilename,
      sizeBytes: row.sizeBytes,
      createdAt: row.createdAt,
    );
  }

  Future<void> softDelete(String uuid) {
    return _dao.softDeleteByUuid(uuid, DateTime.now());
  }

  Stream<PetWeight?> watchLatestWeightForUuid(String petUuid) async* {
    final pet = await _dao.getByUuid(petUuid);
    if (pet == null) {
      yield null;
      return;
    }
    yield* _dao.watchWeightsForPet(pet.id).map((rows) {
      if (rows.isEmpty) return null;
      final row = rows.first;
      return PetWeight(
        measuredAt: row.measuredAt,
        weightKg: row.weightKg,
        note: row.note,
      );
    });
  }

  Pet _toDomain(PetRow row, {List<PetWeightRow>? weights}) {
    return Pet(
      uuid: row.uuid,
      name: row.name,
      species: row.species,
      sex: row.sex,
      isNeutered: row.isNeutered,
      breed: row.breed,
      dateOfBirth: row.dateOfBirth,
      color: row.color,
      markings: row.markings,
      chipNumber: row.chipNumber,
      tassoNumber: row.tassoNumber,
      tassoRegisteredAt: row.tassoRegisteredAt,
      vaccinationPassportNumber: row.vaccinationPassportNumber,
      profilePhotoPath: row.profilePhotoPath,
      allergies: row.allergies,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      householdId: row.householdId,
      weights: (weights ?? const [])
          .map((w) => PetWeight(
                measuredAt: w.measuredAt,
                weightKg: w.weightKg,
                note: w.note,
              ))
          .toList(growable: false),
    );
  }
}
