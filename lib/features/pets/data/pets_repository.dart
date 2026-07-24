import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/media/media_service.dart';
import '../../../core/supabase/current_user.dart';
import '../../sync/data/media_outbox.dart';
import '../../sync/data/sync_outbox.dart';
import '../domain/pet.dart';
import '../domain/pet_enums.dart';
import '../domain/pet_passport_document.dart';

class PetsRepository {
  PetsRepository(this._dao,
      {this.media, this.outbox, this.mediaOutbox, Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final PetsDao _dao;
  final MediaService? media;
  final SyncOutbox? outbox;
  final MediaOutbox? mediaOutbox;
  final Uuid _uuid;

  /// Enqueue an upsert op for [uuid] after a write. No-op if there is no
  /// outbox (local-only tests) or the row has `householdId == null`
  /// (cloud opt-out — plan: null = local-only).
  Future<void> _enqueue(String uuid) async {
    final ob = outbox;
    if (ob == null) return;
    final row = await _dao.getByUuid(uuid);
    if (row == null || row.householdId == null) return;
    await ob.enqueueUpsert(
      entityTable: 'pets',
      entityUuid: row.uuid,
      householdId: row.householdId,
      payload: row.toJson(),
    );
  }

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
    await _enqueue(petUuid);
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
    await _enqueue(uuid);
    // Enqueue an upload if the profile photo landed at a new local
    // path. Nulling out the field (photo removed) enqueues a delete
    // when a storage_key was previously set — otherwise no-op.
    await _handleProfilePhotoChange(
      existing: existing,
      newPath: profilePhotoPath,
      pet: updated,
    );
  }

  Future<void> _handleProfilePhotoChange({
    required PetRow existing,
    required String? newPath,
    required PetRow pet,
  }) async {
    final mo = mediaOutbox;
    final m = media;
    if (mo == null || m == null) return;
    if (pet.householdId == null) return;
    if (newPath == existing.profilePhotoPath) return;
    if (newPath != null) {
      final ext = p.extension(newPath);
      await mo.enqueueUpload(
        entityTable: 'pets',
        entityUuid: pet.uuid,
        localPath: await m.resolve(newPath),
        storageKey: 'household/${pet.householdId}/pets/${pet.uuid}/profile$ext',
        mimeType: _guessMime(ext),
      );
    } else if (existing.profilePhotoStorageKey != null) {
      await mo.enqueueDelete(
        entityTable: 'pets',
        entityUuid: pet.uuid,
        storageKey: existing.profilePhotoStorageKey!,
      );
    }
  }

  String? _guessMime(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
    }
    return null;
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
    await _enqueue(petUuid);
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

  Future<void> softDelete(String uuid) async {
    await _dao.softDeleteByUuid(uuid, DateTime.now());
    await _enqueue(uuid);
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
