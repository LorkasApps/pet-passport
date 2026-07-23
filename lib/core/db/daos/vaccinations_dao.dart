import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
import '../database.dart';
import '../tables/vaccination_documents_table.dart';
import '../tables/vaccinations_table.dart';

part 'vaccinations_dao.g.dart';

@DriftAccessor(tables: [Vaccinations, VaccinationDocuments])
class VaccinationsDao extends DatabaseAccessor<AppDatabase>
    with _$VaccinationsDaoMixin {
  VaccinationsDao(super.db);

  /// Cross-pet stream of administered vaccinations, filtered by
  /// `administeredAt` window. Newest first.
  Stream<List<VaccinationRow>> watchAllInRange({DateTime? from, DateTime? to}) {
    final query = select(vaccinations)..where((v) => v.deletedAt.isNull());
    if (from != null) {
      query.where((v) => v.administeredAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((v) => v.administeredAt.isSmallerOrEqualValue(to));
    }
    query.orderBy([(v) => OrderingTerm.desc(v.administeredAt)]);
    return query.watch();
  }

  Stream<List<VaccinationRow>> watchForPet(int petId) {
    return (select(vaccinations)
          ..where((v) => v.petId.equals(petId) & v.deletedAt.isNull())
          ..orderBy([
            (v) => OrderingTerm.desc(v.administeredAt),
          ]))
        .watch();
  }

  /// Vaccinations with a `next_due_at` in the future, sorted by nearest first.
  Stream<List<VaccinationRow>> watchUpcomingForPet(int petId, DateTime now) {
    return (select(vaccinations)
          ..where(
              (v) => v.petId.equals(petId) & v.nextDueAt.isBiggerThanValue(now) & v.deletedAt.isNull())
          ..orderBy([(v) => OrderingTerm.asc(v.nextDueAt)]))
        .watch();
  }

  Future<VaccinationRow?> getByUuid(String uuid) {
    return (select(vaccinations)..where((v) => v.uuid.equals(uuid) & v.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Stream<VaccinationRow?> watchByUuid(String uuid) {
    return (select(vaccinations)..where((v) => v.uuid.equals(uuid) & v.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<int> insertVaccination(VaccinationsCompanion companion) {
    return into(vaccinations).insert(companion);
  }

  Future<bool> updateVaccination(VaccinationRow row) {
    return update(vaccinations).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(vaccinations)..where((v) => v.uuid.equals(uuid)))
        .write(VaccinationsCompanion(
          deletedAt: Value(deletedAt),
          updatedByUserId: Value(currentUserId()),
        ));
  }

  Future<int> countForPet(int petId) async {
    final row = await (selectOnly(vaccinations)
          ..addColumns([vaccinations.id.count()])
          ..where(vaccinations.petId.equals(petId) & vaccinations.deletedAt.isNull()))
        .getSingle();
    return row.read(vaccinations.id.count()) ?? 0;
  }

  Stream<List<VaccinationDocumentRow>> watchDocumentsForVaccination(
      int vaccinationId) {
    return (select(vaccinationDocuments)
          ..where((d) => d.vaccinationId.equals(vaccinationId))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  Future<int> insertDocument(VaccinationDocumentsCompanion companion) {
    return into(vaccinationDocuments).insert(companion);
  }

  Future<int> deleteDocumentByUuid(String uuid) {
    return (delete(vaccinationDocuments)..where((d) => d.uuid.equals(uuid)))
        .go();
  }

  Future<int> renameDocument(String uuid, String? title) {
    return (update(vaccinationDocuments)
          ..where((d) => d.uuid.equals(uuid)))
        .write(VaccinationDocumentsCompanion(title: Value(title)));
  }

  Future<VaccinationDocumentRow?> getDocumentByUuid(String uuid) {
    return (select(vaccinationDocuments)..where((d) => d.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  /// Returns all future upcoming vaccinations across all pets — used by the
  /// notification scheduler on app boot to re-arm reminders.
  Future<List<VaccinationRow>> getAllUpcoming(DateTime now) {
    return (select(vaccinations)
          ..where((v) => v.nextDueAt.isNotNull() &
              v.nextDueAt.isBiggerThanValue(now) & v.deletedAt.isNull())
          ..orderBy([(v) => OrderingTerm.asc(v.nextDueAt)]))
        .get();
  }
}
