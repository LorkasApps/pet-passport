import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/pet_passport_documents_table.dart';
import '../tables/pet_weights_table.dart';
import '../tables/pets_table.dart';

part 'pets_dao.g.dart';

@DriftAccessor(tables: [Pets, PetWeights, PetPassportDocuments])
class PetsDao extends DatabaseAccessor<AppDatabase> with _$PetsDaoMixin {
  PetsDao(super.db);

  Stream<List<PetRow>> watchActivePets() {
    return (select(pets)
          ..where((p) => p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  Future<PetRow?> getByUuid(String uuid) {
    return (select(pets)..where((p) => p.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<PetRow?> getById(int id) {
    return (select(pets)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Stream<PetRow?> watchByUuid(String uuid) {
    return (select(pets)..where((p) => p.uuid.equals(uuid)))
        .watchSingleOrNull();
  }

  Future<int> insertPet(PetsCompanion companion) {
    return into(pets).insert(companion);
  }

  Future<bool> updatePet(PetRow row) {
    return update(pets).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(pets)..where((p) => p.uuid.equals(uuid)))
        .write(PetsCompanion(deletedAt: Value(deletedAt)));
  }

  Future<int> countActive() async {
    final row = await (selectOnly(pets)
          ..addColumns([pets.id.count()])
          ..where(pets.deletedAt.isNull()))
        .getSingle();
    return row.read(pets.id.count()) ?? 0;
  }

  Stream<List<PetWeightRow>> watchWeightsForPet(int petId) {
    return (select(petWeights)
          ..where((w) => w.petId.equals(petId))
          ..orderBy([(w) => OrderingTerm.desc(w.measuredAt)]))
        .watch();
  }

  Future<int> insertWeight(PetWeightsCompanion companion) {
    return into(petWeights).insert(companion);
  }

  // ── Passport documents ────────────────────────────────────────────────

  Stream<List<PetPassportDocumentRow>> watchPassportDocsForPet(int petId) {
    return (select(petPassportDocuments)
          ..where((d) => d.petId.equals(petId))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  Future<PetPassportDocumentRow?> getPassportDocByUuid(String uuid) {
    return (select(petPassportDocuments)..where((d) => d.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<int> insertPassportDoc(PetPassportDocumentsCompanion companion) {
    return into(petPassportDocuments).insert(companion);
  }

  Future<int> deletePassportDocByUuid(String uuid) {
    return (delete(petPassportDocuments)..where((d) => d.uuid.equals(uuid)))
        .go();
  }
}
