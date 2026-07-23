import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
import '../database.dart';
import '../tables/insurance_documents_table.dart';
import '../tables/insurances_table.dart';

part 'insurances_dao.g.dart';

@DriftAccessor(tables: [Insurances, InsuranceDocuments])
class InsurancesDao extends DatabaseAccessor<AppDatabase>
    with _$InsurancesDaoMixin {
  InsurancesDao(super.db);

  Stream<List<InsuranceRow>> watchForPet(int petId) {
    return (select(insurances)
          ..where((i) => i.petId.equals(petId) & i.deletedAt.isNull())
          ..orderBy([(i) => OrderingTerm.asc(i.provider)]))
        .watch();
  }

  Future<InsuranceRow?> getByUuid(String uuid) {
    return (select(insurances)..where((i) => i.uuid.equals(uuid) & i.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<InsuranceRow?> getByUuidIncludingDeleted(String uuid) {
    return (select(insurances)..where((i) => i.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Stream<InsuranceRow?> watchByUuid(String uuid) {
    return (select(insurances)..where((i) => i.uuid.equals(uuid) & i.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<int> insertInsurance(InsurancesCompanion companion) {
    return into(insurances).insert(companion);
  }

  Future<bool> updateInsurance(InsuranceRow row) {
    return update(insurances).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(insurances)..where((i) => i.uuid.equals(uuid)))
        .write(InsurancesCompanion(
          deletedAt: Value(deletedAt),
          updatedByUserId: Value(currentUserId()),
        ));
  }

  Future<int> countForPet(int petId) async {
    final row = await (selectOnly(insurances)
          ..addColumns([insurances.id.count()])
          ..where(insurances.petId.equals(petId) & insurances.deletedAt.isNull()))
        .getSingle();
    return row.read(insurances.id.count()) ?? 0;
  }

  Stream<List<InsuranceDocumentRow>> watchDocumentsForInsurance(
      int insuranceId) {
    return (select(insuranceDocuments)
          ..where((d) => d.insuranceId.equals(insuranceId))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  Future<int> insertDocument(InsuranceDocumentsCompanion companion) {
    return into(insuranceDocuments).insert(companion);
  }

  Future<int> deleteDocumentByUuid(String uuid) {
    return (delete(insuranceDocuments)..where((d) => d.uuid.equals(uuid)))
        .go();
  }

  Future<int> renameDocument(String uuid, String? title) {
    return (update(insuranceDocuments)
          ..where((d) => d.uuid.equals(uuid)))
        .write(InsuranceDocumentsCompanion(title: Value(title)));
  }

  Future<InsuranceDocumentRow?> getDocumentByUuid(String uuid) {
    return (select(insuranceDocuments)..where((d) => d.uuid.equals(uuid)))
        .getSingleOrNull();
  }
}
