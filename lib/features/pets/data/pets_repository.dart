import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/database.dart';
import '../domain/pet.dart';
import '../domain/pet_enums.dart';

class PetsRepository {
  PetsRepository(this._dao, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final PetsDao _dao;
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
    String? profilePhotoPath,
    String? allergies,
    String? notes,
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
        profilePhotoPath: Value(profilePhotoPath),
        allergies: Value(allergies),
        notes: Value(notes),
        createdAt: now,
        updatedAt: now,
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
      profilePhotoPath: Value(profilePhotoPath),
      allergies: Value(allergies),
      notes: Value(notes),
      updatedAt: DateTime.now(),
    );
    await _dao.updatePet(updated);
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
      profilePhotoPath: row.profilePhotoPath,
      allergies: row.allergies,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
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
