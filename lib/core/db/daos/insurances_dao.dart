import 'package:drift/drift.dart';

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
          ..where((i) => i.petId.equals(petId))
          ..orderBy([(i) => OrderingTerm.asc(i.provider)]))
        .watch();
  }

  Future<InsuranceRow?> getByUuid(String uuid) {
    return (select(insurances)..where((i) => i.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Stream<InsuranceRow?> watchByUuid(String uuid) {
    return (select(insurances)..where((i) => i.uuid.equals(uuid)))
        .watchSingleOrNull();
  }

  Future<int> insertInsurance(InsurancesCompanion companion) {
    return into(insurances).insert(companion);
  }

  Future<bool> updateInsurance(InsuranceRow row) {
    return update(insurances).replace(row);
  }

  Future<int> deleteByUuid(String uuid) {
    return (delete(insurances)..where((i) => i.uuid.equals(uuid))).go();
  }

  Future<int> countForPet(int petId) async {
    final row = await (selectOnly(insurances)
          ..addColumns([insurances.id.count()])
          ..where(insurances.petId.equals(petId)))
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

  Future<InsuranceDocumentRow?> getDocumentByUuid(String uuid) {
    return (select(insuranceDocuments)..where((d) => d.uuid.equals(uuid)))
        .getSingleOrNull();
  }
}
