import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
import '../database.dart';
import '../tables/insurance_documents_table.dart';

part 'insurance_documents_dao.g.dart';

@DriftAccessor(tables: [InsuranceDocuments])
class InsuranceDocumentsDao extends DatabaseAccessor<AppDatabase>
    with _$InsuranceDocumentsDaoMixin {
  InsuranceDocumentsDao(super.db);

  Stream<List<InsuranceDocumentRow>> watchForInsurance(int insuranceId) {
    return (select(insuranceDocuments)
          ..where((d) => d.insuranceId.equals(insuranceId) & d.deletedAt.isNull())
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  Future<InsuranceDocumentRow?> getByUuid(String uuid) {
    return (select(insuranceDocuments)
          ..where((d) => d.uuid.equals(uuid) & d.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<InsuranceDocumentRow?> getByUuidIncludingDeleted(String uuid) {
    return (select(insuranceDocuments)..where((d) => d.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<int> insertDoc(InsuranceDocumentsCompanion companion) {
    return into(insuranceDocuments).insert(companion);
  }

  Future<bool> updateDoc(InsuranceDocumentRow row) {
    return update(insuranceDocuments).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(insuranceDocuments)..where((d) => d.uuid.equals(uuid)))
        .write(InsuranceDocumentsCompanion(
      deletedAt: Value(deletedAt),
      updatedAt: Value(deletedAt),
      updatedByUserId: Value(currentUserId()),
    ));
  }

  Future<int> deleteAllForInsurance(int insuranceId) {
    return (delete(insuranceDocuments)..where((d) => d.insuranceId.equals(insuranceId))).go();
  }

  Future<int> countForInsurance(int insuranceId) async {
    final row = await (selectOnly(insuranceDocuments)
          ..addColumns([insuranceDocuments.id.count()])
          ..where(insuranceDocuments.insuranceId.equals(insuranceId) &
              insuranceDocuments.deletedAt.isNull()))
        .getSingle();
    return row.read(insuranceDocuments.id.count()) ?? 0;
  }
}
