import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_service.dart';
import '../../settings/application/settings_providers.dart';
import '../../sync/application/sync_providers.dart';
import '../data/pets_repository.dart';
import '../domain/pet.dart';
import '../domain/pet_passport_document.dart';

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService();
});

final petsRepositoryProvider = Provider<PetsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final media = ref.watch(mediaServiceProvider);
  final outbox = ref.watch(syncOutboxProvider);
  final mediaOutbox = ref.watch(mediaOutboxProvider);
  return PetsRepository(
    db.petsDao,
    db,
    media: media,
    outbox: outbox,
    mediaOutbox: mediaOutbox,
  );
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

final passportDocsForPetProvider =
    StreamProvider.family<List<PetPassportDocument>, String>((ref, petUuid) {
  return ref.watch(petsRepositoryProvider).watchPassportDocs(petUuid);
});
