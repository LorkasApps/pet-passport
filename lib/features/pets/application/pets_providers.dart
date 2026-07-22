import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_service.dart';
import '../../settings/application/settings_providers.dart';
import '../data/pets_repository.dart';
import '../domain/pet.dart';

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService();
});

final petsRepositoryProvider = Provider<PetsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PetsRepository(db.petsDao);
});

final activePetsProvider = StreamProvider<List<Pet>>((ref) {
  return ref.watch(petsRepositoryProvider).watchActivePets();
});

final petByUuidProvider =
    StreamProvider.family<Pet?, String>((ref, uuid) {
  return ref.watch(petsRepositoryProvider).watchByUuid(uuid);
});

final latestWeightForPetProvider =
    StreamProvider.family<PetWeight?, String>((ref, petUuid) {
  return ref.watch(petsRepositoryProvider).watchLatestWeightForUuid(petUuid);
});
