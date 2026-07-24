import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/pet_documents_dao.dart';
import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/media/media_service.dart';
import '../../../core/supabase/current_user.dart';
import '../../sync/data/media_outbox.dart';
import '../../sync/data/sync_outbox.dart';
import '../domain/pet_document.dart';

class DocumentsRepository {
  DocumentsRepository(
    this._docsDao,
    this._petsDao,
    this._media, {
    this.outbox,
    this.mediaOutbox,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final PetDocumentsDao _docsDao;
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
    final row = await _docsDao.getByUuidIncludingDeleted(uuid);
    if (row == null || row.householdId == null) return;
    await ob.enqueueUpsert(
      entityTable: 'pet_documents',
      entityUuid: row.uuid,
      householdId: row.householdId,
      payload: row.toJson(),
    );
  }

  Stream<List<PetDocument>> watchForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _docsDao.watchForPet(pet.id).map(
          (rows) => rows
              .map((r) => _toDomain(r, petUuid))
              .toList(growable: false),
        );
  }

  Future<int> countForPetUuid(String petUuid) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) return 0;
    return _docsDao.countForPet(pet.id);
  }

  Future<String> attach({
    required String petUuid,
    required File source,
    required String mimeType,
    String? title,
    String? originalFilename,
    int? sizeBytes,
    String? notes,
  }) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) throw StateError('Pet not found: $petUuid');
    final now = DateTime.now();
    final docUuid = _uuid.v4();
    final relative = await _media.savePetDocument(
      petUuid: petUuid,
      docUuid: docUuid,
      source: source,
    );
    await _docsDao.insertDoc(PetDocumentsCompanion.insert(
      uuid: docUuid,
      petId: pet.id,
      title: Value(title),
      filePath: relative,
      mimeType: mimeType,
      originalFilename: Value(originalFilename),
      sizeBytes: Value(sizeBytes),
      notes: Value(notes),
      createdAt: now,
      updatedAt: now,
      householdId: Value(pet.householdId),
      updatedByUserId: Value(currentUserId()),
    ));
    await _enqueue(docUuid);
    // Enqueue an upload once the row exists — guarded on the pet
    // having a household id (cloud opt-out matches the row-outbox
    // guard). The storage key layout puts the entity_uuid at the
    // leaf so the media fetcher can round-trip via the row alone.
    final mo = mediaOutbox;
    if (mo != null && pet.householdId != null) {
      final ext = p.extension(relative);
      await mo.enqueueUpload(
        entityTable: 'pet_documents',
        entityUuid: docUuid,
        localPath: await _media.resolve(relative),
        storageKey:
            'household/${pet.householdId}/pet_documents/$docUuid$ext',
        mimeType: mimeType,
      );
    }
    return docUuid;
  }

  /// Rename / re-annotate a document in place. Passing null clears the
  /// respective field. The underlying file is not touched.
  Future<void> updateMetadata({
    required String uuid,
    String? title,
    String? notes,
  }) async {
    final existing = await _docsDao.getByUuid(uuid);
    if (existing == null) return;
    await _docsDao.updateDoc(existing.copyWith(
      title: Value(title),
      notes: Value(notes),
      updatedAt: DateTime.now(),
      updatedByUserId: Value(currentUserId()),
    ));
    await _enqueue(uuid);
  }

  Future<void> remove(String docUuid) async {
    final row = await _docsDao.getByUuid(docUuid);
    if (row == null) return;
    // Media file stays on disk until a later hard-delete sweep — the
    // sync engine still needs the tombstone row to propagate the
    // deletion to peers. Removing the file immediately would break
    // "row soft-deleted, file already gone" edge cases during a slow
    // pull on the other device.
    await _docsDao.softDeleteByUuid(docUuid, DateTime.now());
    await _enqueue(docUuid);
    // If a storage_key was set (upload had completed), enqueue a
    // delete on the cloud side too. Rows that never uploaded (still
    // pending or opt-out) skip cleanly.
    final mo = mediaOutbox;
    final key = row.storageKey;
    if (mo != null && key != null) {
      await mo.enqueueDelete(
        entityTable: 'pet_documents',
        entityUuid: docUuid,
        storageKey: key,
      );
    }
  }

  PetDocument _toDomain(PetDocumentRow row, String petUuid) {
    return PetDocument(
      uuid: row.uuid,
      petUuid: petUuid,
      title: row.title,
      filePath: row.filePath,
      storageKey: row.storageKey,
      mimeType: row.mimeType,
      originalFilename: row.originalFilename,
      sizeBytes: row.sizeBytes,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
