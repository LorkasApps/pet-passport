import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/appointments_dao.dart';
import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/daos/vets_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/notifications/notification_ids.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/time/recurrence.dart';
import '../domain/appointment.dart';
import '../domain/appointment_enums.dart';
import '../domain/appointment_exception.dart';

/// Aggregate boundary: Appointment = row + reminders + exceptions.
class AppointmentsRepository {
  AppointmentsRepository(
    this._appDao,
    this._petsDao,
    this._vetsDao, {
    this.notifications,
    Uuid? uuid,
    this.expansionHorizon = const Duration(days: 60),
    this.maxOccurrencesPerAppointment = 30,
  }) : _uuid = uuid ?? const Uuid();

  final AppointmentsDao _appDao;
  final PetsDao _petsDao;
  final VetsDao _vetsDao;
  final NotificationService? notifications;
  final Uuid _uuid;
  final Duration expansionHorizon;
  final int maxOccurrencesPerAppointment;

  static const _channelId = 'appointments';
  static const _channelName = 'Appointments';
  static const _channelDesc = 'Reminders for scheduled appointments.';

  Stream<List<Appointment>> watchForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _appDao.watchForPet(pet.id).asyncMap((rows) async {
      final result = <Appointment>[];
      for (final row in rows) {
        result.add(await _toDomain(row, petUuid));
      }
      return result;
    });
  }

  /// Streams appointments for a pet with their next expanded occurrence
  /// inside `[now, now + horizon]`, ordered by occurrence-time.
  Stream<List<UpcomingAppointment>> watchUpcomingForPetUuid(
    String petUuid, {
    Duration horizon = const Duration(days: 30),
  }) async* {
    await for (final list in watchForPetUuid(petUuid)) {
      final now = DateTime.now();
      final to = now.add(horizon);
      final upcoming = <UpcomingAppointment>[];
      for (final a in list) {
        final next = expandRecurrence(
          spec: _specOf(a),
          start: a.startsAt,
          from: now,
          to: to,
          limit: 1,
          exceptions: a.exceptions,
        ).firstOrNull;
        if (next != null) upcoming.add(UpcomingAppointment(a, next));
      }
      upcoming.sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
      yield upcoming;
    }
  }

  Stream<Appointment?> watchByUuid(String uuid, String petUuid) {
    return _appDao.watchByUuid(uuid).asyncMap((row) async {
      if (row == null) return null;
      return _toDomain(row, petUuid);
    });
  }

  Future<Appointment?> getByUuid(String uuid, String petUuid) async {
    final row = await _appDao.getByUuid(uuid);
    if (row == null) return null;
    return _toDomain(row, petUuid);
  }

  Future<String> createAppointment({
    required String petUuid,
    required AppointmentType type,
    required String title,
    required DateTime startsAt,
    int durationMinutes = 60,
    String? vetUuid,
    String? location,
    String? notes,
    RecurrenceFreq recurrenceFreq = RecurrenceFreq.none,
    int recurrenceInterval = 1,
    int recurrenceWeekdays = 0,
    DateTime? recurrenceUntil,
    List<int> reminderOffsetsMinutes = const [60],
  }) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) throw StateError('Pet not found: $petUuid');
    final vetId = vetUuid == null
        ? null
        : (await _vetsDao.getByUuid(vetUuid))?.id;
    final now = DateTime.now();
    final apptUuid = _uuid.v4();
    final id = await _appDao.insertAppointment(AppointmentsCompanion.insert(
      uuid: apptUuid,
      petId: pet.id,
      vetId: Value(vetId),
      type: type,
      title: title,
      startsAt: startsAt,
      durationMinutes: Value(durationMinutes),
      location: Value(location),
      notes: Value(notes),
      recurrenceFreq: Value(recurrenceFreq),
      recurrenceInterval: Value(recurrenceInterval),
      recurrenceWeekdays: Value(recurrenceWeekdays),
      recurrenceUntil: Value(recurrenceUntil),
      createdAt: now,
      updatedAt: now,
    ));
    for (final offset in reminderOffsetsMinutes) {
      await _appDao.insertReminder(AppointmentRemindersCompanion.insert(
        appointmentId: id, offsetMinutes: offset,
      ));
    }
    await _rescheduleFor(apptUuid);
    return apptUuid;
  }

  Future<void> updateAppointment({
    required String uuid,
    required AppointmentType type,
    required String title,
    required DateTime startsAt,
    int durationMinutes = 60,
    String? vetUuid,
    String? location,
    String? notes,
    RecurrenceFreq recurrenceFreq = RecurrenceFreq.none,
    int recurrenceInterval = 1,
    int recurrenceWeekdays = 0,
    DateTime? recurrenceUntil,
    List<int> reminderOffsetsMinutes = const [60],
  }) async {
    final existing = await _appDao.getByUuid(uuid);
    if (existing == null) {
      throw StateError('Appointment not found: $uuid');
    }
    final vetId = vetUuid == null
        ? null
        : (await _vetsDao.getByUuid(vetUuid))?.id;
    await _appDao.updateAppointment(existing.copyWith(
      type: type,
      title: title,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
      vetId: Value(vetId),
      location: Value(location),
      notes: Value(notes),
      recurrenceFreq: recurrenceFreq,
      recurrenceInterval: recurrenceInterval,
      recurrenceWeekdays: recurrenceWeekdays,
      recurrenceUntil: Value(recurrenceUntil),
      updatedAt: DateTime.now(),
    ));
    // Replace reminder rows wholesale.
    await _appDao.deleteRemindersFor(existing.id);
    for (final offset in reminderOffsetsMinutes) {
      await _appDao.insertReminder(AppointmentRemindersCompanion.insert(
        appointmentId: existing.id, offsetMinutes: offset,
      ));
    }
    await notifications?.cancelAllForEntity(entity: 'appt', uuid: uuid);
    await _rescheduleFor(uuid);
  }

  Future<void> deleteByUuid(String uuid) async {
    await notifications?.cancelAllForEntity(entity: 'appt', uuid: uuid);
    await _appDao.deleteByUuid(uuid);
  }

  Future<void> rescheduleAllUpcomingReminders() async {
    final notif = notifications;
    if (notif == null) return;
    final rows = await _appDao.getAllActive(DateTime.now());
    for (final row in rows) {
      await _rescheduleForRow(row);
    }
  }

  Future<void> _rescheduleFor(String uuid) async {
    final row = await _appDao.getByUuid(uuid);
    if (row == null) return;
    await _rescheduleForRow(row);
  }

  Future<void> _rescheduleForRow(AppointmentRow row) async {
    final notif = notifications;
    if (notif == null) return;
    final now = DateTime.now();
    final to = now.add(expansionHorizon);
    final reminderRows = await _appDao.getRemindersFor(row.id);
    final exceptionRows = await _appDao.getExceptionsFor(row.id);
    final offsets = reminderRows.map((r) => r.offsetMinutes).toList();
    if (offsets.isEmpty) offsets.add(60); // sensible default
    final exceptions = exceptionRows
        .map((e) => AppointmentException(
              occurrenceStart: e.occurrenceStart,
              isCancelled: e.isCancelled,
              overrideStartsAt: e.overrideStartsAt,
            ))
        .toList();
    final spec = _specOfRow(row);
    final occurrences = expandRecurrence(
      spec: spec,
      start: row.startsAt,
      from: now.subtract(const Duration(days: 1)),
      to: to,
      limit: maxOccurrencesPerAppointment,
      exceptions: exceptions,
    );
    final pet = await _petsDao.getById(row.petId);
    final petName = pet?.name ?? '';
    for (final occ in occurrences) {
      for (final offset in offsets) {
        final when = occ.subtract(Duration(minutes: offset));
        if (!when.isAfter(now)) continue;
        final slot = NotificationIds.slotFor(
          occurrenceStart: occ, offsetMinutes: offset,
        );
        await notif.scheduleReminder(
          entity: 'appt',
          uuid: row.uuid,
          slot: slot,
          channelId: _channelId,
          channelName: _channelName,
          channelDescription: _channelDesc,
          title: petName.isEmpty ? row.title : '$petName: ${row.title}',
          body: row.title,
          whenLocal: when,
        );
      }
    }
  }

  RecurrenceSpec _specOf(Appointment a) => RecurrenceSpec(
        freq: a.recurrenceFreq,
        interval: a.recurrenceInterval,
        weekdaysBitmask: a.recurrenceWeekdays,
        until: a.recurrenceUntil,
      );

  RecurrenceSpec _specOfRow(AppointmentRow row) => RecurrenceSpec(
        freq: row.recurrenceFreq,
        interval: row.recurrenceInterval,
        weekdaysBitmask: row.recurrenceWeekdays,
        until: row.recurrenceUntil,
      );

  Future<Appointment> _toDomain(AppointmentRow row, String petUuid) async {
    String? vetUuid;
    final vId = row.vetId;
    if (vId != null) {
      final vet = await _vetsDao.getById(vId);
      vetUuid = vet?.uuid;
    }
    final reminderRows = await _appDao.getRemindersFor(row.id);
    final exceptionRows = await _appDao.getExceptionsFor(row.id);
    return Appointment(
      uuid: row.uuid,
      petUuid: petUuid,
      type: row.type,
      title: row.title,
      startsAt: row.startsAt,
      durationMinutes: row.durationMinutes,
      vetUuid: vetUuid,
      location: row.location,
      notes: row.notes,
      recurrenceFreq: row.recurrenceFreq,
      recurrenceInterval: row.recurrenceInterval,
      recurrenceWeekdays: row.recurrenceWeekdays,
      recurrenceUntil: row.recurrenceUntil,
      reminderOffsetsMinutes:
          reminderRows.map((r) => r.offsetMinutes).toList(growable: false),
      exceptions: exceptionRows
          .map((e) => AppointmentException(
                occurrenceStart: e.occurrenceStart,
                isCancelled: e.isCancelled,
                overrideStartsAt: e.overrideStartsAt,
              ))
          .toList(growable: false),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

class UpcomingAppointment {
  const UpcomingAppointment(this.appointment, this.nextOccurrence);
  final Appointment appointment;
  final DateTime nextOccurrence;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
