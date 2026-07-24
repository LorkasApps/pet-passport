import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/insurances_dao.dart';
import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/media/media_service.dart';
import '../../../core/supabase/current_user.dart';
import '../../sync/data/media_outbox.dart';
import '../../sync/data/sync_outbox.dart';
import '../domain/insurance.dart';

class InsurancesRepository {
  InsurancesRepository(
    this._insurancesDao,
    this._petsDao,
    this._media, {
    this.outbox,
    this.mediaOutbox,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final InsurancesDao _insurancesDao;
  final PetsDao _petsDao;
  final MediaService _media;
  final SyncOutbox? outbox;
  final MediaOutbox? mediaOutbox;
  final Uuid _uuid;

  /// Enqueue an upsert op for [uuid] after a write. No-op if there is no
  /// outbox (local-only tests) or the row has `householdId == null`
  /// (cloud opt-out — plan: null = local-only).
  Future<void> _enqueue(String uuid) async {
    final ob = outbox;
    if (ob == null) return;
    final row = await _insurancesDao.getByUuidIncludingDeleted(uuid);
    if (row == null || row.householdId == null) return;
    await ob.enqueueUpsert(
      entityTable: 'insurances',
      entityUuid: row.uuid,
      householdId: row.householdId,
      payload: row.toJson(),
    );
  }

  Stream<List<Insurance>> watchForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _insurancesDao.watchForPet(pet.id).asyncMap((rows) async {
      final result = <Insurance>[];
      for (final row in rows) {
        final docs =
            await _insurancesDao.watchDocumentsForInsurance(row.id).first;
        result.add(_toDomain(row, petUuid, docs));
      }
      return result;
    });
  }

  Future<int> countForPetUuid(String petUuid) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) return 0;
    return _insurancesDao.countForPet(pet.id);
  }

  Stream<Insurance?> watchByUuid(String uuid, String petUuid) {
    return _insurancesDao.watchByUuid(uuid).asyncMap((row) async {
      if (row == null) return null;
      final docs =
          await _insurancesDao.watchDocumentsForInsurance(row.id).first;
      return _toDomain(row, petUuid, docs);
    });
  }

  Future<String> createInsurance({
    required String petUuid,
    required String provider,
    String? policyNumber,
    DateTime? contractStart,
    DateTime? contractEnd,
    String? notes,
  }) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) throw StateError('Pet not found: $petUuid');
    final now = DateTime.now();
    final insUuid = _uuid.v4();
    await _insurancesDao.insertInsurance(InsurancesCompanion.insert(
      uuid: insUuid,
      petId: pet.id,
      provider: provider,
      policyNumber: Value(policyNumber),
      contractStart: Value(contractStart),
      contractEnd: Value(contractEnd),
      notes: Value(notes),
      createdAt: now,
      updatedAt: now,
      updatedByUserId: Value(currentUserId()),
      householdId: Value(pet.householdId),
    ));
    await _enqueue(insUuid);
    return insUuid;
  }

  Future<void> updateInsurance({
    required String uuid,
    required String provider,
    String? policyNumber,
    DateTime? contractStart,
    DateTime? contractEnd,
    String? notes,
  }) async {
    final existing = await _insurancesDao.getByUuid(uuid);
    if (existing == null) {
      throw StateError('Insurance not found: $uuid');
    }
    await _insurancesDao.updateInsurance(existing.copyWith(
      provider: provider,
      policyNumber: Value(policyNumber),
      contractStart: Value(contractStart),
      contractEnd: Value(contractEnd),
      notes: Value(notes),
      updatedAt: DateTime.now(),
      updatedByUserId: Value(currentUserId()),
    ));
    await _enqueue(uuid);
  }

  Future<void> deleteByUuid(String uuid) async {
    // Files linger — startup sweep would clean orphans, but we can be tidy.
    final row = await _insurancesDao.getByUuid(uuid);
    if (row == null) return;
    final docs =
        await _insurancesDao.watchDocumentsForInsurance(row.id).first;
    for (final d in docs) {
      await _media.deleteFile(d.filePath);
    }
    await _insurancesDao.softDeleteByUuid(uuid, DateTime.now());
    await _enqueue(uuid);
  }

  /// Enqueue an upsert op for insurance_document [uuid] after a write. No-op if there is no
  /// outbox (local-only tests) or the parent insurance has `householdId == null`.
  Future<void> _enqueueInsuranceDocument(String uuid) async {
    final ob = outbox;
    if (ob == null) return;
    final row = await _insurancesDao.getDocumentByUuidIncludingDeleted(uuid);
    if (row == null || row.householdId == null) return;
    await ob.enqueueUpsert(
      entityTable: 'insurance_documents',
      entityUuid: row.uuid,
      householdId: row.householdId,
      payload: row.toJson(),
    );
  }

  Future<String> attachDocument({
    required String insuranceUuid,
    required File source,
    required String mimeType,
    String? originalFilename,
    int? sizeBytes,
  }) async {
    final ins = await _insurancesDao.getByUuid(insuranceUuid);
    if (ins == null) throw StateError('Insurance not found: $insuranceUuid');
    final docUuid = _uuid.v4();
    final now = DateTime.now();
    final relative = await _media.saveInsuranceDocument(
      insuranceUuid: insuranceUuid,
      docUuid: docUuid,
      source: source,
    );
    await _insurancesDao.insertDocument(InsuranceDocumentsCompanion.insert(
      uuid: docUuid,
      insuranceId: ins.id,
      filePath: relative,
      mimeType: mimeType,
      originalFilename: Value(originalFilename),
      sizeBytes: Value(sizeBytes),
      createdAt: now,
      updatedByUserId: Value(currentUserId()),
      householdId: Value(ins.householdId),
    ));
    await _enqueueInsuranceDocument(docUuid);
    final mo = mediaOutbox;
    if (mo != null && ins.householdId != null) {
      final ext = p.extension(relative);
      await mo.enqueueUpload(
        entityTable: 'insurance_documents',
        entityUuid: docUuid,
        localPath: await _media.resolve(relative),
        storageKey:
            'household/${ins.householdId}/insurance_documents/$docUuid$ext',
        mimeType: mimeType,
      );
    }
    return docUuid;
  }

  Future<void> removeDocument(String docUuid) async {
    final row = await _insurancesDao.getDocumentByUuid(docUuid);
    if (row == null) return;
    await _insurancesDao.softDeleteDocumentByUuid(docUuid, DateTime.now());
    await _enqueueInsuranceDocument(docUuid);
    final mo = mediaOutbox;
    final key = row.storageKey;
    if (mo != null && key != null) {
      await mo.enqueueDelete(
        entityTable: 'insurance_documents',
        entityUuid: docUuid,
        storageKey: key,
      );
    }
    await _media.deleteFile(row.filePath);
  }

  /// Rename an insurance document — only the [title] column changes; the
  /// underlying file and `original_filename` are left alone. Passing an
  /// empty string clears the title.
  Future<void> renameDocument(String docUuid, String? title) async {
    final trimmed = title?.trim();
    await _insurancesDao.renameDocument(
      docUuid,
      trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
  }

  Insurance _toDomain(
    InsuranceRow row,
    String petUuid,
    List<InsuranceDocumentRow> docs,
  ) {
    return Insurance(
      uuid: row.uuid,
      petUuid: petUuid,
      provider: row.provider,
      policyNumber: row.policyNumber,
      contractStart: row.contractStart,
      contractEnd: row.contractEnd,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      documents: docs
          .map((d) => InsuranceDocument(
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
}
