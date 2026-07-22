import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../pets/application/pets_providers.dart';
import '../../pets/domain/pet.dart';
import '../../settings/application/settings_providers.dart';
import '../domain/timeline_entry.dart';
import 'timeline_filter.dart';

/// Cross-pet timeline: merges events, administered vaccinations,
/// medication intakes and past appointments into a single reverse-chrono
/// list. All work happens in-memory after the DAO stream fan-in — the
/// dataset is small enough (weeks-to-months of a single owner's activity)
/// that this stays under a millisecond per rebuild.
final timelineEntriesProvider =
    StreamProvider.family<List<TimelineEntry>, TimelineFilter>(
        (ref, filter) async* {
  final db = ref.watch(databaseProvider);
  final petsAsync = ref.watch(activePetsProvider);
  final pets = petsAsync.valueOrNull;
  if (pets == null) {
    yield const [];
    return;
  }

  // petId → Pet lookup for the row → domain translation.
  final petsById = <int, Pet>{};
  for (final p in pets) {
    final row = await db.petsDao.getByUuid(p.uuid);
    if (row != null) petsById[row.id] = p;
  }

  final selectedPetId = filter.petUuid == null
      ? null
      : (await db.petsDao.getByUuid(filter.petUuid!))?.id;

  final wantEvents = filter.kinds.contains(TimelineKind.event);
  final wantVacs = filter.kinds.contains(TimelineKind.vaccination);
  final wantIntakes = filter.kinds.contains(TimelineKind.medicationIntake);
  final wantAppts = filter.kinds.contains(TimelineKind.appointment);

  // Sources — an empty stream shortcut when the kind is filtered out.
  final eventsStream = wantEvents
      ? db.eventsDao.watchAllInRange(from: filter.from, to: filter.to)
      : Stream<List<EventRow>>.value(const []);
  final vacsStream = wantVacs
      ? db.vaccinationsDao.watchAllInRange(from: filter.from, to: filter.to)
      : Stream<List<VaccinationRow>>.value(const []);
  final intakesStream = wantIntakes
      ? db.medicationsDao
          .watchAllIntakesInRange(from: filter.from, to: filter.to)
      : Stream<List<MedicationIntakeRow>>.value(const []);
  final apptsStream = wantAppts
      ? db.appointmentsDao.watchAllInRange(from: filter.from, to: filter.to)
      : Stream<List<AppointmentRow>>.value(const []);

  // medId → (uuid, name, petUuid). Repopulated whenever the medications
  // table changes so renamed rows show correctly. Uses watch() so we get
  // reactive updates alongside the intakes stream.
  var medsById = <int, ({String uuid, String name, String petUuid})>{};
  final medsStream = db.select(db.medications).watch();

  List<EventRow> lastEvents = const [];
  List<VaccinationRow> lastVacs = const [];
  List<MedicationIntakeRow> lastIntakes = const [];
  List<AppointmentRow> lastAppts = const [];

  List<TimelineEntry> assemble() {
    final entries = <TimelineEntry>[];

    if (wantEvents) {
      for (final e in lastEvents) {
        if (selectedPetId != null && e.petId != selectedPetId) continue;
        final pet = petsById[e.petId];
        if (pet == null) continue;
        entries.add(TimelineEntry(
          kind: TimelineKind.event,
          entityUuid: e.uuid,
          petUuid: pet.uuid,
          petName: pet.name,
          at: e.occurredAt,
          title: e.title ?? _eventTypeLabel(e.eventType),
          subtitle: e.note,
          icon: _eventTypeIcon(e.eventType),
          route: '/pets/${pet.uuid}/events/${e.uuid}',
        ));
      }
    }

    if (wantVacs) {
      for (final v in lastVacs) {
        if (selectedPetId != null && v.petId != selectedPetId) continue;
        final pet = petsById[v.petId];
        if (pet == null) continue;
        entries.add(TimelineEntry(
          kind: TimelineKind.vaccination,
          entityUuid: v.uuid,
          petUuid: pet.uuid,
          petName: pet.name,
          at: v.administeredAt,
          title: v.vaccineName,
          subtitle: v.batchNumber,
          icon: Icons.vaccines_outlined,
          route: '/pets/${pet.uuid}/vaccinations/${v.uuid}',
        ));
      }
    }

    if (wantIntakes) {
      for (final i in lastIntakes) {
        final med = medsById[i.medicationId];
        if (med == null) continue;
        if (selectedPetId != null && filter.petUuid != med.petUuid) continue;
        final pet = pets.firstWhere(
          (p) => p.uuid == med.petUuid,
          orElse: () => pets.first,
        );
        entries.add(TimelineEntry(
          kind: TimelineKind.medicationIntake,
          entityUuid: i.uuid,
          petUuid: pet.uuid,
          petName: pet.name,
          at: i.takenAt,
          title: med.name,
          subtitle: i.skipped ? null : i.note,
          icon: i.skipped
              ? Icons.remove_circle_outline
              : Icons.medication_outlined,
          route: '/pets/${pet.uuid}/medications/${med.uuid}/intakes',
        ));
      }
    }

    if (wantAppts) {
      final now = DateTime.now();
      for (final a in lastAppts) {
        if (selectedPetId != null && a.petId != selectedPetId) continue;
        if (a.startsAt.isAfter(now)) continue; // upcoming lives in Termine
        final pet = petsById[a.petId];
        if (pet == null) continue;
        entries.add(TimelineEntry(
          kind: TimelineKind.appointment,
          entityUuid: a.uuid,
          petUuid: pet.uuid,
          petName: pet.name,
          at: a.startsAt,
          title: a.title,
          subtitle: a.location,
          icon: Icons.event_available_outlined,
          route: '/pets/${pet.uuid}/appointments/${a.uuid}',
        ));
      }
    }

    entries.sort((a, b) => b.at.compareTo(a.at));
    return entries;
  }

  final controller = StreamController<List<TimelineEntry>>();
  final subs = <StreamSubscription<Object?>>[];
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
    controller.close();
  });

  subs.add(medsStream.listen((rows) {
    medsById = {
      for (final r in rows)
        r.id: (
          uuid: r.uuid,
          name: r.name,
          petUuid: petsById[r.petId]?.uuid ?? '',
        ),
    };
    controller.add(assemble());
  }));
  subs.add(eventsStream.listen((rows) {
    lastEvents = rows;
    controller.add(assemble());
  }));
  subs.add(vacsStream.listen((rows) {
    lastVacs = rows;
    controller.add(assemble());
  }));
  subs.add(intakesStream.listen((rows) {
    lastIntakes = rows;
    controller.add(assemble());
  }));
  subs.add(apptsStream.listen((rows) {
    lastAppts = rows;
    controller.add(assemble());
  }));

  yield const [];
  yield* controller.stream;
});

String _eventTypeLabel(Object type) => type.toString().split('.').last;

IconData _eventTypeIcon(Object type) {
  switch (type.toString().split('.').last) {
    case 'weight':
      return Icons.monitor_weight_outlined;
    case 'feeding':
      return Icons.restaurant_outlined;
    case 'symptom':
      return Icons.sick_outlined;
    case 'activity':
      return Icons.directions_walk_outlined;
    default:
      return Icons.note_outlined;
  }
}

