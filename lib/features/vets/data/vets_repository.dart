import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/daos/vets_dao.dart';
import '../../../core/db/database.dart';
import '../domain/vet.dart';

class VetsRepository {
  VetsRepository(this._vetsDao, this._petsDao, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final VetsDao _vetsDao;
  final PetsDao _petsDao;
  final Uuid _uuid;

  Stream<List<Vet>> watchForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _vetsDao.watchForPet(pet.id).map(
          (rows) => rows
              .map((r) => _toDomain(r, petUuid))
              .toList(growable: false),
        );
  }

  Stream<List<Vet>> watchActiveForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _vetsDao.watchActiveForPet(pet.id).map(
          (rows) => rows
              .map((r) => _toDomain(r, petUuid))
              .toList(growable: false),
        );
  }

  Future<int> countForPetUuid(String petUuid) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) return 0;
    return _vetsDao.countForPet(pet.id);
  }

  Stream<Vet?> watchByUuid(String uuid, String petUuid) {
    return _vetsDao.watchByUuid(uuid).map(
          (row) => row == null ? null : _toDomain(row, petUuid),
        );
  }

  Future<String> createVet({
    required String petUuid,
    required String name,
    String? practice,
    String? address,
    String? phone,
    String? email,
    String? notes,
    bool isActive = true,
  }) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) throw StateError('Pet not found: $petUuid');
    final now = DateTime.now();
    final vetUuid = _uuid.v4();
    await _vetsDao.insertVet(VetsCompanion.insert(
      uuid: vetUuid,
      petId: pet.id,
      name: name,
      practice: Value(practice),
      address: Value(address),
      phone: Value(phone),
      email: Value(email),
      notes: Value(notes),
      isActive: Value(isActive),
      createdAt: now,
      updatedAt: now,
    ));
    return vetUuid;
  }

  Future<void> updateVet({
    required String uuid,
    required String name,
    String? practice,
    String? address,
    String? phone,
    String? email,
    String? notes,
    bool isActive = true,
  }) async {
    final existing = await _vetsDao.getByUuid(uuid);
    if (existing == null) {
      throw StateError('Vet not found: $uuid');
    }
    await _vetsDao.updateVet(existing.copyWith(
      name: name,
      practice: Value(practice),
      address: Value(address),
      phone: Value(phone),
      email: Value(email),
      notes: Value(notes),
      isActive: isActive,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> setActive(String uuid, bool isActive) async {
    final existing = await _vetsDao.getByUuid(uuid);
    if (existing == null) return;
    await _vetsDao.updateVet(existing.copyWith(
      isActive: isActive,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> deleteByUuid(String uuid) {
    return _vetsDao.deleteByUuid(uuid);
  }

  Vet _toDomain(VetRow row, String petUuid) {
    return Vet(
      uuid: row.uuid,
      petUuid: petUuid,
      name: row.name,
      practice: row.practice,
      address: row.address,
      phone: row.phone,
      email: row.email,
      notes: row.notes,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
