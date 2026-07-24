import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pets/application/pets_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../sync/application/sync_providers.dart';
import '../data/insurances_repository.dart';
import '../domain/insurance.dart';

final insurancesRepositoryProvider =
    Provider<InsurancesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final media = ref.watch(mediaServiceProvider);
  final outbox = ref.watch(syncOutboxProvider);
  final mediaOutbox = ref.watch(mediaOutboxProvider);
  return InsurancesRepository(
    db.insurancesDao,
    db.petsDao,
    media,
    outbox: outbox,
    mediaOutbox: mediaOutbox,
  );
});

final insurancesForPetProvider =
    StreamProvider.family<List<Insurance>, String>((ref, petUuid) {
  return ref.watch(insurancesRepositoryProvider).watchForPetUuid(petUuid);
});

final insuranceCountForPetProvider =
    StreamProvider.family<int, String>((ref, petUuid) {
  return ref
      .watch(insurancesRepositoryProvider)
      .watchForPetUuid(petUuid)
      .map((list) => list.length);
});

final insuranceByUuidProvider = StreamProvider.family<
    Insurance?, ({String insuranceUuid, String petUuid})>((ref, args) {
  return ref
      .watch(insurancesRepositoryProvider)
      .watchByUuid(args.insuranceUuid, args.petUuid);
});
