import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/daos/vaccinations_dao.dart';
import '../../../core/db/daos/vets_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/media/media_service.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/vaccination.dart';

class VaccinationsRepository {
  VaccinationsRepository(
    this._vacDao,
    this._petsDao,
    this._vetsDao, {
    this.notifications,
    this.media,
    this.reminderLead = const Duration(days: 7),
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final VaccinationsDao _vacDao;
  final PetsDao _petsDao;
  final VetsDao _vetsDao;
  final NotificationService? notifications;
  final MediaService? media;
  final Duration reminderLead;
  final Uuid _uuid;

  Stream<List<Vaccination>> watchForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _vacDao.watchForPet(pet.id).asyncMap((rows) async {
      final result = <Vaccination>[];
      for (final row in rows) {
        result.add(await _toDomain(row, petUuid));
      }
      return result;
    });
  }

  Stream<List<Vaccination>> watchUpcomingForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _vacDao
        .watchUpcomingForPet(pet.id, DateTime.now())
        .asyncMap((rows) async {
      final result = <Vaccination>[];
      for (final row in rows) {
        result.add(await _toDomain(row, petUuid));
      }
      return result;
    });
  }

  Stream<Vaccination?> watchByUuid(String uuid, String petUuid) {
    return _vacDao.watchByUuid(uuid).asyncMap((row) async {
      if (row == null) return null;
      return _toDomain(row, petUuid);
    });
  }

  Future<Vaccination?> getByUuid(String uuid, String petUuid) async {
    final row = await _vacDao.getByUuid(uuid);
    if (row == null) return null;
    return _toDomain(row, petUuid);
  }

  Future<String> createVaccination({
    required String petUuid,
    required String vaccineName,
    required DateTime administeredAt,
    DateTime? nextDueAt,
    String? vetUuid,
    String? batchNumber,
    String? notes,
  }) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) throw StateError('Pet not found: $petUuid');
    final vetId = vetUuid == null ? null : (await _vetsDao.getByUuid(vetUuid))?.id;
    final now = DateTime.now();
    final vacUuid = _uuid.v4();
    await _vacDao.insertVaccination(VaccinationsCompanion.insert(
      uuid: vacUuid,
      petId: pet.id,
      vaccineName: vaccineName,
      administeredAt: administeredAt,
      nextDueAt: Value(nextDueAt),
      vetId: Value(vetId),
      batchNumber: Value(batchNumber),
      notes: Value(notes),
      createdAt: now,
      updatedAt: now,
    ));
    await _rescheduleReminder(
      uuid: vacUuid,
      petName: pet.name,
      vaccineName: vaccineName,
      nextDueAt: nextDueAt,
    );
    return vacUuid;
  }

  Future<void> updateVaccination({
    required String uuid,
    required String vaccineName,
    required DateTime administeredAt,
    DateTime? nextDueAt,
    String? vetUuid,
    String? batchNumber,
    String? notes,
  }) async {
    final existing = await _vacDao.getByUuid(uuid);
    if (existing == null) {
      throw StateError('Vaccination not found: $uuid');
    }
    final vetId = vetUuid == null ? null : (await _vetsDao.getByUuid(vetUuid))?.id;
    await _vacDao.updateVaccination(existing.copyWith(
      vaccineName: vaccineName,
      administeredAt: administeredAt,
      nextDueAt: Value(nextDueAt),
      vetId: Value(vetId),
      batchNumber: Value(batchNumber),
      notes: Value(notes),
      updatedAt: DateTime.now(),
    ));
    final pet = await _petsDao.getById(existing.petId);
    await _rescheduleReminder(
      uuid: uuid,
      petName: pet?.name ?? '',
      vaccineName: vaccineName,
      nextDueAt: nextDueAt,
    );
  }

  /// Re-arms notifications for every upcoming vaccination. Idempotent (IDs
  /// are deterministic per vaccination UUID). Call on app boot to recover
  /// from device restarts and permission changes.
  Future<void> rescheduleAllUpcomingReminders() async {
    final notif = notifications;
    if (notif == null) return;
    final rows = await _vacDao.getAllUpcoming(DateTime.now());
    for (final row in rows) {
      final pet = await _petsDao.getById(row.petId);
      final petName = pet?.name ?? '';
      final due = row.nextDueAt;
      if (due == null) continue;
      final when = due.subtract(reminderLead);
      await notif.scheduleVaccinationReminder(
        uuid: row.uuid,
        title: petName.isEmpty
            ? 'Impfung fällig: ${row.vaccineName}'
            : '$petName: Impfung fällig',
        body: row.vaccineName,
        whenLocal: when.isAfter(DateTime.now()) ? when : due,
      );
    }
  }

  Future<void> deleteByUuid(String uuid) async {
    final row = await _vacDao.getByUuid(uuid);
    if (row != null) {
      final docs = await _vacDao.watchDocumentsForVaccination(row.id).first;
      for (final d in docs) {
        await media?.deleteFile(d.filePath);
      }
    }
    await _vacDao.deleteByUuid(uuid);
    await notifications?.cancelVaccinationReminder(uuid);
  }

  Future<void> _rescheduleReminder({
    required String uuid,
    required String petName,
    required String vaccineName,
    required DateTime? nextDueAt,
  }) async {
    final notif = notifications;
    if (notif == null) return;
    if (nextDueAt == null) {
      await notif.cancelVaccinationReminder(uuid);
      return;
    }
    final when = nextDueAt.subtract(reminderLead);
    await notif.scheduleVaccinationReminder(
      uuid: uuid,
      title: petName.isEmpty
          ? 'Impfung fällig: $vaccineName'
          : '$petName: Impfung fällig',
      body: vaccineName,
      whenLocal: when.isAfter(DateTime.now()) ? when : nextDueAt,
    );
  }

  Future<Vaccination> _toDomain(VaccinationRow row, String petUuid) async {
    String? vetUuid;
    final vId = row.vetId;
    if (vId != null) {
      final vet = await _vetsDao.getById(vId);
      vetUuid = vet?.uuid;
    }
    final docs = await _vacDao.watchDocumentsForVaccination(row.id).first;
    return Vaccination(
      uuid: row.uuid,
      petUuid: petUuid,
      vaccineName: row.vaccineName,
      administeredAt: row.administeredAt,
      nextDueAt: row.nextDueAt,
      vetUuid: vetUuid,
      batchNumber: row.batchNumber,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      documents: docs
          .map((d) => VaccinationDocument(
                uuid: d.uuid,
                title: d.title,
                filePath: d.filePath,
                mimeType: d.mimeType,
                originalFilename: d.originalFilename,
                sizeBytes: d.sizeBytes,
                createdAt: d.createdAt,
              ))
          .toList(growable: false),
    );
  }

  Future<String> attachDocument({
    required String vaccinationUuid,
    required File source,
    required String mimeType,
    String? originalFilename,
    int? sizeBytes,
  }) async {
    final mediaService = media;
    if (mediaService == null) {
      throw StateError('MediaService not wired — cannot attach documents');
    }
    final vac = await _vacDao.getByUuid(vaccinationUuid);
    if (vac == null) {
      throw StateError('Vaccination not found: $vaccinationUuid');
    }
    final docUuid = _uuid.v4();
    final relative = await mediaService.saveVaccinationDocument(
      vaccinationUuid: vaccinationUuid,
      docUuid: docUuid,
      source: source,
    );
    await _vacDao.insertDocument(VaccinationDocumentsCompanion.insert(
      uuid: docUuid,
      vaccinationId: vac.id,
      filePath: relative,
      mimeType: mimeType,
      originalFilename: Value(originalFilename),
      sizeBytes: Value(sizeBytes),
      createdAt: DateTime.now(),
    ));
    return docUuid;
  }

  Future<void> removeDocument(String docUuid) async {
    final row = await _vacDao.getDocumentByUuid(docUuid);
    if (row == null) return;
    await _vacDao.deleteDocumentByUuid(docUuid);
    await media?.deleteFile(row.filePath);
  }

  /// Rename a vaccination document — only the [title] column changes;
  /// underlying file + `original_filename` stay untouched. Empty string
  /// clears the title.
  Future<void> renameDocument(String docUuid, String? title) async {
    final trimmed = title?.trim();
    await _vacDao.renameDocument(
      docUuid,
      trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
  }
}
