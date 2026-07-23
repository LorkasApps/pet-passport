import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../data/vets_repository.dart';
import '../domain/vet.dart';

final vetsRepositoryProvider = Provider<VetsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return VetsRepository(db.vetsDao, db.petsDao);
});

final vetsForPetProvider =
    StreamProvider.family<List<Vet>, String>((ref, petUuid) {
  return ref.watch(vetsRepositoryProvider).watchForPetUuid(petUuid);
});

final activeVetsForPetProvider =
    StreamProvider.family<List<Vet>, String>((ref, petUuid) {
  return ref.watch(vetsRepositoryProvider).watchActiveForPetUuid(petUuid);
});

final vetCountForPetProvider =
    StreamProvider.family<int, String>((ref, petUuid) {
  return ref
      .watch(vetsRepositoryProvider)
      .watchActiveForPetUuid(petUuid)
      .map((list) => list.length);
});

final vetByUuidProvider =
    StreamProvider.family<Vet?, ({String vetUuid, String petUuid})>((
  ref,
  args,
) {
  return ref
      .watch(vetsRepositoryProvider)
      .watchByUuid(args.vetUuid, args.petUuid);
});
