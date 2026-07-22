import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/medication_intakes_table.dart';
import '../tables/medication_reminders_table.dart';
import '../tables/medications_table.dart';

part 'medications_dao.g.dart';

@DriftAccessor(tables: [Medications, MedicationReminders, MedicationIntakes])
class MedicationsDao extends DatabaseAccessor<AppDatabase>
    with _$MedicationsDaoMixin {
  MedicationsDao(super.db);

  Stream<List<MedicationRow>> watchForPet(int petId) {
    return (select(medications)
          ..where((m) => m.petId.equals(petId))
          ..orderBy([
            (m) => OrderingTerm.desc(m.isActive),
            (m) => OrderingTerm.asc(m.name),
          ]))
        .watch();
  }

  Stream<List<MedicationRow>> watchActiveForPet(int petId) {
    return (select(medications)
          ..where((m) => m.petId.equals(petId) & m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.name)]))
        .watch();
  }

  Future<MedicationRow?> getByUuid(String uuid) {
    return (select(medications)..where((m) => m.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Stream<MedicationRow?> watchByUuid(String uuid) {
    return (select(medications)..where((m) => m.uuid.equals(uuid)))
        .watchSingleOrNull();
  }

  Future<int> insertMedication(MedicationsCompanion companion) {
    return into(medications).insert(companion);
  }

  Future<bool> updateMedication(MedicationRow row) {
    return update(medications).replace(row);
  }

  Future<int> deleteByUuid(String uuid) {
    return (delete(medications)..where((m) => m.uuid.equals(uuid))).go();
  }

  /// All active medications whose `ends_at` has not passed. Boot-reschedule
  /// uses this to re-arm notifications after device restart.
  Future<List<MedicationRow>> getAllActive(DateTime now) {
    return (select(medications)
          ..where((m) =>
              m.isActive.equals(true) &
              (m.endsAt.isNull() | m.endsAt.isBiggerOrEqualValue(now))))
        .get();
  }

  // --- reminders ---

  Future<List<MedicationReminderRow>> getRemindersFor(int medicationId) {
    return (select(medicationReminders)
          ..where((r) => r.medicationId.equals(medicationId)))
        .get();
  }

  Future<int> insertReminder(MedicationRemindersCompanion companion) {
    return into(medicationReminders).insert(companion);
  }

  Future<int> deleteRemindersFor(int medicationId) {
    return (delete(medicationReminders)
          ..where((r) => r.medicationId.equals(medicationId)))
        .go();
  }

  // --- intakes ---

  /// Cross-medication stream of intakes, filtered by `takenAt` window.
  /// Newest first. Used by the cross-pet timeline.
  Stream<List<MedicationIntakeRow>> watchAllIntakesInRange({
    DateTime? from,
    DateTime? to,
  }) {
    final query = select(medicationIntakes);
    if (from != null) {
      query.where((i) => i.takenAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((i) => i.takenAt.isSmallerOrEqualValue(to));
    }
    query.orderBy([(i) => OrderingTerm.desc(i.takenAt)]);
    return query.watch();
  }

  Stream<List<MedicationIntakeRow>> watchIntakesFor(int medicationId) {
    return (select(medicationIntakes)
          ..where((i) => i.medicationId.equals(medicationId))
          ..orderBy([(i) => OrderingTerm.desc(i.takenAt)]))
        .watch();
  }

  Future<int> insertIntake(MedicationIntakesCompanion companion) {
    return into(medicationIntakes).insert(companion);
  }

  Future<int> deleteIntakeByUuid(String uuid) {
    return (delete(medicationIntakes)..where((i) => i.uuid.equals(uuid))).go();
  }

  Future<int> countIntakesSince(int medicationId, DateTime since) async {
    final row = await (selectOnly(medicationIntakes)
          ..addColumns([medicationIntakes.id.count()])
          ..where(
            medicationIntakes.medicationId.equals(medicationId) &
                medicationIntakes.takenAt.isBiggerOrEqualValue(since) &
                medicationIntakes.skipped.equals(false),
          ))
        .getSingle();
    return row.read(medicationIntakes.id.count()) ?? 0;
  }
}
