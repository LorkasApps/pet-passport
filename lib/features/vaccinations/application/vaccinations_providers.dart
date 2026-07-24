import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pets/application/pets_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../sync/application/sync_providers.dart';
import '../data/vaccinations_repository.dart';
import '../domain/vaccination.dart';

final vaccinationsRepositoryProvider =
    Provider<VaccinationsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final notif = ref.watch(notificationServiceProvider);
  final media = ref.watch(mediaServiceProvider);
  final leadDays = ref.watch(reminderLeadDaysProvider);
  final outbox = ref.watch(syncOutboxProvider);
  final mediaOutbox = ref.watch(mediaOutboxProvider);
  return VaccinationsRepository(
    db.vaccinationsDao,
    db.petsDao,
    db.vetsDao,
    notifications: notif,
    media: media,
    outbox: outbox,
    mediaOutbox: mediaOutbox,
    reminderLead: Duration(days: leadDays),
  );
});

final vaccinationsForPetProvider =
    StreamProvider.family<List<Vaccination>, String>((ref, petUuid) {
  return ref
      .watch(vaccinationsRepositoryProvider)
      .watchForPetUuid(petUuid);
});

final upcomingVaccinationsForPetProvider =
    StreamProvider.family<List<Vaccination>, String>((ref, petUuid) {
  return ref
      .watch(vaccinationsRepositoryProvider)
      .watchUpcomingForPetUuid(petUuid);
});

final vaccinationByUuidProvider = StreamProvider.family<
    Vaccination?, ({String vaccinationUuid, String petUuid})>((ref, args) {
  return ref
      .watch(vaccinationsRepositoryProvider)
      .watchByUuid(args.vaccinationUuid, args.petUuid);
});
