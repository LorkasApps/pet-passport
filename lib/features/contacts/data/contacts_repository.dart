import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/contacts_dao.dart';
import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/supabase/current_user.dart';
import '../domain/contact.dart';
import '../domain/contact_enums.dart';

class ContactsRepository {
  ContactsRepository(this._contactsDao, this._petsDao, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final ContactsDao _contactsDao;
  final PetsDao _petsDao;
  final Uuid _uuid;

  Stream<List<Contact>> watchForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _contactsDao.watchForPet(pet.id).map(
          (rows) => rows
              .map((r) => _toDomain(r, petUuid))
              .toList(growable: false),
        );
  }

  Stream<List<Contact>> watchActiveForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _contactsDao.watchActiveForPet(pet.id).map(
          (rows) => rows
              .map((r) => _toDomain(r, petUuid))
              .toList(growable: false),
        );
  }

  Future<int> countForPetUuid(String petUuid) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) return 0;
    return _contactsDao.countForPet(pet.id);
  }

  Stream<Contact?> watchByUuid(String uuid, String petUuid) {
    return _contactsDao.watchByUuid(uuid).map(
          (row) => row == null ? null : _toDomain(row, petUuid),
        );
  }

  Future<String> createContact({
    required String petUuid,
    required String name,
    required ContactRole role,
    String? organization,
    String? address,
    String? phone,
    String? email,
    String? notes,
    bool isActive = true,
  }) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) throw StateError('Pet not found: $petUuid');
    final now = DateTime.now();
    final contactUuid = _uuid.v4();
    await _contactsDao.insertContact(ContactsCompanion.insert(
      uuid: contactUuid,
      petId: pet.id,
      role: Value(role),
      name: name,
      organization: Value(organization),
      address: Value(address),
      phone: Value(phone),
      email: Value(email),
      notes: Value(notes),
      isActive: Value(isActive),
      createdAt: now,
      updatedAt: now,
      updatedByUserId: Value(currentUserId()),
    ));
    return contactUuid;
  }

  Future<void> updateContact({
    required String uuid,
    required String name,
    required ContactRole role,
    String? organization,
    String? address,
    String? phone,
    String? email,
    String? notes,
    bool isActive = true,
  }) async {
    final existing = await _contactsDao.getByUuid(uuid);
    if (existing == null) {
      throw StateError('Contact not found: $uuid');
    }
    await _contactsDao.updateContact(existing.copyWith(
      role: role,
      name: name,
      organization: Value(organization),
      address: Value(address),
      phone: Value(phone),
      email: Value(email),
      notes: Value(notes),
      isActive: isActive,
      updatedAt: DateTime.now(),
      updatedByUserId: Value(currentUserId()),
    ));
  }

  Future<void> setActive(String uuid, bool isActive) async {
    final existing = await _contactsDao.getByUuid(uuid);
    if (existing == null) return;
    await _contactsDao.updateContact(existing.copyWith(
      isActive: isActive,
      updatedAt: DateTime.now(),
      updatedByUserId: Value(currentUserId()),
    ));
  }

  Future<void> deleteByUuid(String uuid) {
    return _contactsDao.deleteByUuid(uuid);
  }

  Contact _toDomain(ContactRow row, String petUuid) {
    return Contact(
      uuid: row.uuid,
      petUuid: petUuid,
      role: row.role,
      name: row.name,
      organization: row.organization,
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
