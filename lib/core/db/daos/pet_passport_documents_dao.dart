import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
import '../database.dart';
import '../tables/pet_passport_documents_table.dart';

part 'pet_passport_documents_dao.g.dart';

@DriftAccessor(tables: [PetPassportDocuments])
class PetPassportDocumentsDao extends DatabaseAccessor<AppDatabase>
    with _$PetPassportDocumentsDaoMixin {
  PetPassportDocumentsDao(super.db);

  Stream<List<PetPassportDocumentRow>> watchForPet(int petId) {
    return (select(petPassportDocuments)
          ..where((d) => d.petId.equals(petId) & d.deletedAt.isNull())
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  Future<PetPassportDocumentRow?> getByUuid(String uuid) {
    return (select(petPassportDocuments)
          ..where((d) => d.uuid.equals(uuid) & d.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<PetPassportDocumentRow?> getByUuidIncludingDeleted(String uuid) {
    return (select(petPassportDocuments)..where((d) => d.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<int> insertDoc(PetPassportDocumentsCompanion companion) {
    return into(petPassportDocuments).insert(companion);
  }

  Future<bool> updateDoc(PetPassportDocumentRow row) {
    return update(petPassportDocuments).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(petPassportDocuments)..where((d) => d.uuid.equals(uuid)))
        .write(PetPassportDocumentsCompanion(
      deletedAt: Value(deletedAt),
      updatedAt: Value(deletedAt),
      updatedByUserId: Value(currentUserId()),
    ));
  }

  Future<int> deleteAllForPet(int petId) {
    return (delete(petPassportDocuments)..where((d) => d.petId.equals(petId))).go();
  }

  Future<int> countForPet(int petId) async {
    final row = await (selectOnly(petPassportDocuments)
          ..addColumns([petPassportDocuments.id.count()])
          ..where(petPassportDocuments.petId.equals(petId) &
              petPassportDocuments.deletedAt.isNull()))
        .getSingle();
    return row.read(petPassportDocuments.id.count()) ?? 0;
  }
}
