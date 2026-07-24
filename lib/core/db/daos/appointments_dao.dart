import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
import '../database.dart';
import '../tables/appointment_exceptions_table.dart';
import '../tables/appointment_reminders_table.dart';
import '../tables/appointments_table.dart';

part 'appointments_dao.g.dart';

@DriftAccessor(tables: [Appointments, AppointmentReminders, AppointmentExceptions])
class AppointmentsDao extends DatabaseAccessor<AppDatabase>
    with _$AppointmentsDaoMixin {
  AppointmentsDao(super.db);

  Stream<List<AppointmentRow>> watchForPet(int petId) {
    return (select(appointments)
          ..where((a) => a.petId.equals(petId) & a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.startsAt)]))
        .watch();
  }

  Stream<List<AppointmentRow>> watchAll() {
    return (select(appointments)
          ..where((a) => a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.startsAt)]))
        .watch();
  }

  /// Cross-pet stream, filtered by `startsAt` window. Newest first.
  /// Recurring appointments are returned by their base row only; occurrence
  /// expansion is a job for the caller.
  Stream<List<AppointmentRow>> watchAllInRange({DateTime? from, DateTime? to}) {
    final query = select(appointments)..where((a) => a.deletedAt.isNull());
    if (from != null) {
      query.where((a) => a.startsAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((a) => a.startsAt.isSmallerOrEqualValue(to));
    }
    query.orderBy([(a) => OrderingTerm.desc(a.startsAt)]);
    return query.watch();
  }

  Future<AppointmentRow?> getByUuid(String uuid) {
    return (select(appointments)..where((a) => a.uuid.equals(uuid) & a.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<AppointmentRow?> getByUuidIncludingDeleted(String uuid) {
    return (select(appointments)..where((a) => a.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Stream<AppointmentRow?> watchByUuid(String uuid) {
    return (select(appointments)..where((a) => a.uuid.equals(uuid) & a.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<int> insertAppointment(AppointmentsCompanion companion) {
    return into(appointments).insert(companion);
  }

  Future<bool> updateAppointment(AppointmentRow row) {
    return update(appointments).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(appointments)..where((a) => a.uuid.equals(uuid)))
        .write(AppointmentsCompanion(
          deletedAt: Value(deletedAt),
          updatedAt: Value(deletedAt),
          updatedByUserId: Value(currentUserId()),
        ));
  }

  /// All rows whose starts_at is in the future OR whose recurrence_until is
  /// in the future (i.e. still generating occurrences). Boot-reschedule uses
  /// this to re-arm notifications.
  Future<List<AppointmentRow>> getAllActive(DateTime now) {
    return (select(appointments)
          ..where((a) =>
              (a.startsAt.isBiggerOrEqualValue(now) |
              a.recurrenceUntil.isBiggerOrEqualValue(now)) & a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.startsAt)]))
        .get();
  }

  // --- reminders ---

  Future<List<AppointmentReminderRow>> getRemindersFor(int appointmentId) {
    return (select(appointmentReminders)
          ..where((r) => r.appointmentId.equals(appointmentId)))
        .get();
  }

  Stream<List<AppointmentReminderRow>> watchRemindersFor(int appointmentId) {
    return (select(appointmentReminders)
          ..where((r) => r.appointmentId.equals(appointmentId)))
        .watch();
  }

  Future<int> insertReminder(AppointmentRemindersCompanion companion) {
    return into(appointmentReminders).insert(companion);
  }

  Future<int> deleteRemindersFor(int appointmentId) {
    return (delete(appointmentReminders)
          ..where((r) => r.appointmentId.equals(appointmentId)))
        .go();
  }

  // --- exceptions ---

  Future<List<AppointmentExceptionRow>> getExceptionsFor(int appointmentId) {
    return (select(appointmentExceptions)
          ..where((e) => e.appointmentId.equals(appointmentId)))
        .get();
  }

  Stream<List<AppointmentExceptionRow>> watchExceptionsFor(int appointmentId) {
    return (select(appointmentExceptions)
          ..where((e) => e.appointmentId.equals(appointmentId)))
        .watch();
  }

  Future<int> upsertException(AppointmentExceptionsCompanion companion) {
    return into(appointmentExceptions).insert(
      companion,
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<int> deleteExceptionsFor(int appointmentId) {
    return (delete(appointmentExceptions)
          ..where((e) => e.appointmentId.equals(appointmentId)))
        .go();
  }
}
