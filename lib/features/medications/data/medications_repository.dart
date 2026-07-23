import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/medications_dao.dart';
import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/daos/vets_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/notifications/notification_ids.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/supabase/current_user.dart';
import '../../../core/time/recurrence.dart';
import '../../../core/time/time_of_day_json.dart';
import '../../appointments/domain/appointment_enums.dart';
import '../domain/medication.dart';
import '../domain/medication_enums.dart';
import '../domain/medication_intake.dart';

class MedicationsRepository {
  MedicationsRepository(
    this._medDao,
    this._petsDao,
    this._vetsDao, {
    this.notifications,
    Uuid? uuid,
    this.expansionHorizon = const Duration(days: 30),
    this.maxOccurrencesPerMedication = 60,
  }) : _uuid = uuid ?? const Uuid();

  final MedicationsDao _medDao;
  final PetsDao _petsDao;
  final VetsDao _vetsDao;
  final NotificationService? notifications;
  final Uuid _uuid;
  final Duration expansionHorizon;
  final int maxOccurrencesPerMedication;

  static const _channelId = 'medications';
  static const _channelName = 'Medications';
  static const _channelDesc = 'Reminders for scheduled medication doses.';

  Stream<List<Medication>> watchForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _medDao.watchForPet(pet.id).asyncMap((rows) async {
      final result = <Medication>[];
      for (final row in rows) {
        result.add(await _toDomain(row, petUuid));
      }
      return result;
    });
  }

  Stream<List<Medication>> watchActiveForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _medDao.watchActiveForPet(pet.id).asyncMap((rows) async {
      final result = <Medication>[];
      for (final row in rows) {
        result.add(await _toDomain(row, petUuid));
      }
      return result;
    });
  }

  Stream<Medication?> watchByUuid(String uuid, String petUuid) {
    return _medDao.watchByUuid(uuid).asyncMap((row) async {
      if (row == null) return null;
      return _toDomain(row, petUuid);
    });
  }

  Future<Medication?> getByUuid(String uuid, String petUuid) async {
    final row = await _medDao.getByUuid(uuid);
    if (row == null) return null;
    return _toDomain(row, petUuid);
  }

  Future<String> createMedication({
    required String petUuid,
    required String name,
    required double dosageAmount,
    required String dosageUnit,
    required FreqType freqType,
    int freqInterval = 1,
    int freqWeekdays = 0,
    List<String> timesOfDay = const [],
    required DateTime startsAt,
    DateTime? endsAt,
    bool isActive = true,
    String? notes,
    String? prescribedByVetUuid,
    List<int> reminderOffsetsMinutes = const [0],
    bool withFood = false,
  }) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) throw StateError('Pet not found: $petUuid');
    final vetId = prescribedByVetUuid == null
        ? null
        : (await _vetsDao.getByUuid(prescribedByVetUuid))?.id;
    final now = DateTime.now();
    final medUuid = _uuid.v4();
    final id = await _medDao.insertMedication(MedicationsCompanion.insert(
      uuid: medUuid,
      petId: pet.id,
      name: name,
      dosageAmount: Value(dosageAmount),
      dosageUnit: Value(dosageUnit),
      freqType: Value(freqType),
      freqInterval: Value(freqInterval),
      freqWeekdays: Value(freqWeekdays),
      timesOfDayJson: Value(TimeOfDayJson.encode(timesOfDay)),
      startsAt: startsAt,
      endsAt: Value(endsAt),
      isActive: Value(isActive),
      notes: Value(notes),
      prescribedByVetId: Value(vetId),
      withFood: Value(withFood),
      createdAt: now,
      updatedAt: now,
      updatedByUserId: Value(currentUserId()),
    ));
    for (final offset in reminderOffsetsMinutes) {
      await _medDao.insertReminder(MedicationRemindersCompanion.insert(
        medicationId: id, offsetMinutes: offset,
      ));
    }
    await _rescheduleFor(medUuid);
    return medUuid;
  }

  Future<void> updateMedication({
    required String uuid,
    required String name,
    required double dosageAmount,
    required String dosageUnit,
    required FreqType freqType,
    int freqInterval = 1,
    int freqWeekdays = 0,
    List<String> timesOfDay = const [],
    required DateTime startsAt,
    DateTime? endsAt,
    bool isActive = true,
    String? notes,
    String? prescribedByVetUuid,
    List<int> reminderOffsetsMinutes = const [0],
    bool withFood = false,
  }) async {
    final existing = await _medDao.getByUuid(uuid);
    if (existing == null) {
      throw StateError('Medication not found: $uuid');
    }
    final vetId = prescribedByVetUuid == null
        ? null
        : (await _vetsDao.getByUuid(prescribedByVetUuid))?.id;
    await _medDao.updateMedication(existing.copyWith(
      name: name,
      dosageAmount: dosageAmount,
      dosageUnit: dosageUnit,
      freqType: freqType,
      freqInterval: freqInterval,
      freqWeekdays: freqWeekdays,
      timesOfDayJson: TimeOfDayJson.encode(timesOfDay),
      startsAt: startsAt,
      endsAt: Value(endsAt),
      isActive: isActive,
      notes: Value(notes),
      prescribedByVetId: Value(vetId),
      withFood: withFood,
      updatedAt: DateTime.now(),
      updatedByUserId: Value(currentUserId()),
    ));
    await _medDao.deleteRemindersFor(existing.id);
    for (final offset in reminderOffsetsMinutes) {
      await _medDao.insertReminder(MedicationRemindersCompanion.insert(
        medicationId: existing.id, offsetMinutes: offset,
      ));
    }
    await notifications?.cancelAllForEntity(entity: 'med', uuid: uuid);
    await _rescheduleFor(uuid);
  }

  Future<void> deleteByUuid(String uuid) async {
    await notifications?.cancelAllForEntity(entity: 'med', uuid: uuid);
    await _medDao.deleteByUuid(uuid);
  }

  // --- intake ---

  Stream<List<MedicationIntake>> watchIntakes(String medicationUuid) async* {
    final row = await _medDao.getByUuid(medicationUuid);
    if (row == null) {
      yield const [];
      return;
    }
    yield* _medDao.watchIntakesFor(row.id).map((rows) => rows
        .map((r) => MedicationIntake(
              uuid: r.uuid,
              medicationUuid: medicationUuid,
              takenAt: r.takenAt,
              skipped: r.skipped,
              note: r.note,
            ))
        .toList(growable: false));
  }

  Future<void> logIntake({
    required String medicationUuid,
    DateTime? takenAt,
    bool skipped = false,
    String? note,
  }) async {
    final row = await _medDao.getByUuid(medicationUuid);
    if (row == null) return;
    await _medDao.insertIntake(MedicationIntakesCompanion.insert(
      uuid: _uuid.v4(),
      medicationId: row.id,
      takenAt: takenAt ?? DateTime.now(),
      skipped: Value(skipped),
      note: Value(note),
      updatedByUserId: Value(currentUserId()),
    ));
  }

  Future<void> deleteIntake(String intakeUuid) async {
    await _medDao.deleteIntakeByUuid(intakeUuid);
  }

  /// Adherence over the last 7 days: (taken, expected). `expected` counts
  /// scheduled occurrences in the window per recurrence spec × times-of-day.
  Future<({int taken, int expected})> adherenceLast7Days(
      String medicationUuid) async {
    final row = await _medDao.getByUuid(medicationUuid);
    if (row == null) return (taken: 0, expected: 0);
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: 7));
    final taken = await _medDao.countIntakesSince(row.id, windowStart);
    final expected = _expectedDoses(
      row, from: windowStart, to: now,
    );
    return (taken: taken, expected: expected);
  }

  Future<void> rescheduleAllUpcomingReminders() async {
    final notif = notifications;
    if (notif == null) return;
    final rows = await _medDao.getAllActive(DateTime.now());
    for (final row in rows) {
      await _rescheduleForRow(row);
    }
  }

  Future<void> _rescheduleFor(String uuid) async {
    final row = await _medDao.getByUuid(uuid);
    if (row == null) return;
    await _rescheduleForRow(row);
  }

  Future<void> _rescheduleForRow(MedicationRow row) async {
    final notif = notifications;
    if (notif == null || !row.isActive) return;
    final now = DateTime.now();
    final to = now.add(expansionHorizon);
    final endsAt = row.endsAt;
    final horizonEnd = endsAt != null && endsAt.isBefore(to) ? endsAt : to;
    final reminderRows = await _medDao.getRemindersFor(row.id);
    final offsets = reminderRows.map((r) => r.offsetMinutes).toList();
    if (offsets.isEmpty) offsets.add(0);
    final times = TimeOfDayJson.decode(row.timesOfDayJson);
    if (times.isEmpty) return;
    final spec = _specOfRow(row);
    final pet = await _petsDao.getById(row.petId);
    final petName = pet?.name ?? '';

    int emitted = 0;
    // For each recurrence day, emit one notification per time-of-day.
    final dayStarts = expandRecurrence(
      spec: spec,
      start: DateTime(row.startsAt.year, row.startsAt.month, row.startsAt.day),
      from: DateTime(now.year, now.month, now.day),
      to: horizonEnd,
      limit: maxOccurrencesPerMedication,
    );
    for (final day in dayStarts) {
      for (final t in times) {
        final parts = t.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final occ = DateTime(day.year, day.month, day.day, hour, minute);
        if (occ.isBefore(row.startsAt) || occ.isAfter(horizonEnd)) continue;
        for (final offset in offsets) {
          final when = occ.subtract(Duration(minutes: offset));
          if (!when.isAfter(now)) continue;
          final slot = NotificationIds.slotFor(
            occurrenceStart: occ, offsetMinutes: offset,
          );
          await notif.scheduleReminder(
            entity: 'med',
            uuid: row.uuid,
            slot: slot,
            channelId: _channelId,
            channelName: _channelName,
            channelDescription: _channelDesc,
            title: petName.isEmpty ? row.name : '$petName: ${row.name}',
            body: _buildBody(row),
            whenLocal: when,
            extra: const {'action': 'log'},
          );
          emitted++;
          if (emitted >= maxOccurrencesPerMedication) return;
        }
      }
    }
  }

  int _expectedDoses(MedicationRow row,
      {required DateTime from, required DateTime to}) {
    final times = TimeOfDayJson.decode(row.timesOfDayJson);
    if (times.isEmpty) return 0;
    final spec = _specOfRow(row);
    final dayStarts = expandRecurrence(
      spec: spec,
      start: DateTime(row.startsAt.year, row.startsAt.month, row.startsAt.day),
      from: DateTime(from.year, from.month, from.day),
      to: to,
    );
    var count = 0;
    for (final day in dayStarts) {
      for (final t in times) {
        final parts = t.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final occ = DateTime(day.year, day.month, day.day, hour, minute);
        if (!occ.isBefore(from) && !occ.isAfter(to)) count++;
      }
    }
    return count;
  }

  RecurrenceSpec _specOfRow(MedicationRow row) {
    switch (row.freqType) {
      case FreqType.daily:
        return RecurrenceSpec(
          freq: RecurrenceFreq.daily,
          interval: row.freqInterval,
          until: row.endsAt,
        );
      case FreqType.weekly:
        return RecurrenceSpec(
          freq: RecurrenceFreq.weekly,
          interval: row.freqInterval,
          weekdaysBitmask: row.freqWeekdays,
          until: row.endsAt,
        );
      case FreqType.intervalDays:
        return RecurrenceSpec(
          freq: RecurrenceFreq.daily,
          interval: row.freqInterval,
          until: row.endsAt,
        );
    }
  }

  String _buildBody(MedicationRow row) {
    final withFoodSuffix = row.withFood ? ' · mit Futter' : '';
    if (row.dosageAmount <= 0) return '${row.name}$withFoodSuffix';
    final unit = row.dosageUnit.isEmpty ? '' : ' ${row.dosageUnit}';
    final amount = row.dosageAmount % 1 == 0
        ? row.dosageAmount.toStringAsFixed(0)
        : row.dosageAmount.toString();
    return '${row.name} — $amount$unit$withFoodSuffix';
  }

  Future<Medication> _toDomain(MedicationRow row, String petUuid) async {
    String? vetUuid;
    final vId = row.prescribedByVetId;
    if (vId != null) {
      final vet = await _vetsDao.getById(vId);
      vetUuid = vet?.uuid;
    }
    final reminderRows = await _medDao.getRemindersFor(row.id);
    return Medication(
      uuid: row.uuid,
      petUuid: petUuid,
      name: row.name,
      dosageAmount: row.dosageAmount,
      dosageUnit: row.dosageUnit,
      freqType: row.freqType,
      freqInterval: row.freqInterval,
      freqWeekdays: row.freqWeekdays,
      timesOfDay: TimeOfDayJson.decode(row.timesOfDayJson),
      startsAt: row.startsAt,
      endsAt: row.endsAt,
      isActive: row.isActive,
      notes: row.notes,
      prescribedByVetUuid: vetUuid,
      reminderOffsetsMinutes:
          reminderRows.map((r) => r.offsetMinutes).toList(growable: false),
      withFood: row.withFood,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
