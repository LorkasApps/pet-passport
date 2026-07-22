import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../data/medications_repository.dart';
import '../domain/medication.dart';
import '../domain/medication_intake.dart';

final medicationsRepositoryProvider = Provider<MedicationsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final notif = ref.watch(notificationServiceProvider);
  return MedicationsRepository(
    db.medicationsDao,
    db.petsDao,
    db.vetsDao,
    notifications: notif,
  );
});

final medicationsForPetProvider =
    StreamProvider.family<List<Medication>, String>((ref, petUuid) {
  return ref.watch(medicationsRepositoryProvider).watchForPetUuid(petUuid);
});

final activeMedicationsForPetProvider =
    StreamProvider.family<List<Medication>, String>((ref, petUuid) {
  return ref
      .watch(medicationsRepositoryProvider)
      .watchActiveForPetUuid(petUuid);
});

final medicationByUuidProvider = StreamProvider.family<
    Medication?, ({String medUuid, String petUuid})>((ref, args) {
  return ref
      .watch(medicationsRepositoryProvider)
      .watchByUuid(args.medUuid, args.petUuid);
});

final medicationIntakesProvider =
    StreamProvider.family<List<MedicationIntake>, String>((ref, medUuid) {
  return ref.watch(medicationsRepositoryProvider).watchIntakes(medUuid);
});

final adherenceLast7DaysProvider = FutureProvider.family<
    ({int taken, int expected}), String>((ref, medUuid) {
  return ref
      .watch(medicationsRepositoryProvider)
      .adherenceLast7Days(medUuid);
});
