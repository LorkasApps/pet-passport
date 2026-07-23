import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
import '../database.dart';
import '../tables/vets_table.dart';

part 'vets_dao.g.dart';

@DriftAccessor(tables: [Vets])
class VetsDao extends DatabaseAccessor<AppDatabase> with _$VetsDaoMixin {
  VetsDao(super.db);

  Stream<List<VetRow>> watchForPet(int petId) {
    return (select(vets)
          ..where((v) => v.petId.equals(petId) & v.deletedAt.isNull())
          ..orderBy([
            (v) => OrderingTerm.desc(v.isActive),
            (v) => OrderingTerm.asc(v.name),
          ]))
        .watch();
  }

  Stream<List<VetRow>> watchActiveForPet(int petId) {
    return (select(vets)
          ..where((v) => v.petId.equals(petId) & v.isActive.equals(true) & v.deletedAt.isNull())
          ..orderBy([(v) => OrderingTerm.asc(v.name)]))
        .watch();
  }

  Future<VetRow?> getByUuid(String uuid) {
    return (select(vets)..where((v) => v.uuid.equals(uuid) & v.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<VetRow?> getByUuidIncludingDeleted(String uuid) {
    return (select(vets)..where((v) => v.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<VetRow?> getById(int id) {
    return (select(vets)..where((v) => v.id.equals(id) & v.deletedAt.isNull())).getSingleOrNull();
  }

  Stream<VetRow?> watchByUuid(String uuid) {
    return (select(vets)..where((v) => v.uuid.equals(uuid) & v.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<int> insertVet(VetsCompanion companion) {
    return into(vets).insert(companion);
  }

  Future<bool> updateVet(VetRow row) {
    return update(vets).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(vets)..where((v) => v.uuid.equals(uuid)))
        .write(VetsCompanion(
          deletedAt: Value(deletedAt),
          updatedByUserId: Value(currentUserId()),
        ));
  }

  Future<int> countForPet(int petId) async {
    final row = await (selectOnly(vets)
          ..addColumns([vets.id.count()])
          ..where(vets.petId.equals(petId) & vets.deletedAt.isNull()))
        .getSingle();
    return row.read(vets.id.count()) ?? 0;
  }
}
