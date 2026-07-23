import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/pet_documents_dao.dart';
import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/media/media_service.dart';
import '../../../core/supabase/current_user.dart';
import '../domain/pet_document.dart';

class DocumentsRepository {
  DocumentsRepository(
    this._docsDao,
    this._petsDao,
    this._media, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final PetDocumentsDao _docsDao;
  final PetsDao _petsDao;
  final MediaService _media;
  final Uuid _uuid;

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
  }

  PetDocument _toDomain(PetDocumentRow row, String petUuid) {
    return PetDocument(
      uuid: row.uuid,
      petUuid: petUuid,
      title: row.title,
      filePath: row.filePath,
      mimeType: row.mimeType,
      originalFilename: row.originalFilename,
      sizeBytes: row.sizeBytes,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
