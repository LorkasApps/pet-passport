import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/vets_table.dart';

part 'vets_dao.g.dart';

@DriftAccessor(tables: [Vets])
class VetsDao extends DatabaseAccessor<AppDatabase> with _$VetsDaoMixin {
  VetsDao(super.db);

  Stream<List<VetRow>> watchForPet(int petId) {
    return (select(vets)
          ..where((v) => v.petId.equals(petId))
          ..orderBy([(v) => OrderingTerm.asc(v.name)]))
        .watch();
  }

  Future<VetRow?> getByUuid(String uuid) {
    return (select(vets)..where((v) => v.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<VetRow?> getById(int id) {
    return (select(vets)..where((v) => v.id.equals(id))).getSingleOrNull();
  }

  Stream<VetRow?> watchByUuid(String uuid) {
    return (select(vets)..where((v) => v.uuid.equals(uuid)))
        .watchSingleOrNull();
  }

  Future<int> insertVet(VetsCompanion companion) {
    return into(vets).insert(companion);
  }

  Future<bool> updateVet(VetRow row) {
    return update(vets).replace(row);
  }

  Future<int> deleteByUuid(String uuid) {
    return (delete(vets)..where((v) => v.uuid.equals(uuid))).go();
  }

  Future<int> countForPet(int petId) async {
    final row = await (selectOnly(vets)
          ..addColumns([vets.id.count()])
          ..where(vets.petId.equals(petId)))
        .getSingle();
    return row.read(vets.id.count()) ?? 0;
  }
}
