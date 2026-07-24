import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
import '../database.dart';
import '../tables/vaccination_documents_table.dart';

part 'vaccination_documents_dao.g.dart';

@DriftAccessor(tables: [VaccinationDocuments])
class VaccinationDocumentsDao extends DatabaseAccessor<AppDatabase>
    with _$VaccinationDocumentsDaoMixin {
  VaccinationDocumentsDao(super.db);

  Stream<List<VaccinationDocumentRow>> watchForVaccination(int vaccinationId) {
    return (select(vaccinationDocuments)
          ..where((d) => d.vaccinationId.equals(vaccinationId) & d.deletedAt.isNull())
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  Future<VaccinationDocumentRow?> getByUuid(String uuid) {
    return (select(vaccinationDocuments)
          ..where((d) => d.uuid.equals(uuid) & d.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<VaccinationDocumentRow?> getByUuidIncludingDeleted(String uuid) {
    return (select(vaccinationDocuments)..where((d) => d.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<int> insertDoc(VaccinationDocumentsCompanion companion) {
    return into(vaccinationDocuments).insert(companion);
  }

  Future<bool> updateDoc(VaccinationDocumentRow row) {
    return update(vaccinationDocuments).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(vaccinationDocuments)..where((d) => d.uuid.equals(uuid)))
        .write(VaccinationDocumentsCompanion(
      deletedAt: Value(deletedAt),
      updatedAt: Value(deletedAt),
      updatedByUserId: Value(currentUserId()),
    ));
  }

  Future<int> deleteAllForVaccination(int vaccinationId) {
    return (delete(vaccinationDocuments)..where((d) => d.vaccinationId.equals(vaccinationId))).go();
  }

  Future<int> countForVaccination(int vaccinationId) async {
    final row = await (selectOnly(vaccinationDocuments)
          ..addColumns([vaccinationDocuments.id.count()])
          ..where(vaccinationDocuments.vaccinationId.equals(vaccinationId) &
              vaccinationDocuments.deletedAt.isNull()))
        .getSingle();
    return row.read(vaccinationDocuments.id.count()) ?? 0;
  }
}
