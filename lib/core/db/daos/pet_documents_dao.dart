import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/pet_documents_table.dart';

part 'pet_documents_dao.g.dart';

@DriftAccessor(tables: [PetDocuments])
class PetDocumentsDao extends DatabaseAccessor<AppDatabase>
    with _$PetDocumentsDaoMixin {
  PetDocumentsDao(super.db);

  Stream<List<PetDocumentRow>> watchForPet(int petId) {
    return (select(petDocuments)
          ..where((d) => d.petId.equals(petId))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  Future<PetDocumentRow?> getByUuid(String uuid) {
    return (select(petDocuments)..where((d) => d.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<int> insertDoc(PetDocumentsCompanion companion) {
    return into(petDocuments).insert(companion);
  }

  Future<bool> updateDoc(PetDocumentRow row) {
    return update(petDocuments).replace(row);
  }

  Future<int> deleteByUuid(String uuid) {
    return (delete(petDocuments)..where((d) => d.uuid.equals(uuid))).go();
  }

  Future<int> deleteAllForPet(int petId) {
    return (delete(petDocuments)..where((d) => d.petId.equals(petId))).go();
  }

  Future<int> countForPet(int petId) async {
    final row = await (selectOnly(petDocuments)
          ..addColumns([petDocuments.id.count()])
          ..where(petDocuments.petId.equals(petId)))
        .getSingle();
    return row.read(petDocuments.id.count()) ?? 0;
  }
}
