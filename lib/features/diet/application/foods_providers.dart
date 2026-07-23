import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pets/application/pets_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../data/foods_repository.dart';
import '../domain/food.dart';
import '../domain/food_photo.dart';

final foodsRepositoryProvider = Provider<FoodsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final notif = ref.watch(notificationServiceProvider);
  return FoodsRepository(
    db.foodsDao,
    db.petsDao,
    notifications: notif,
    media: ref.watch(mediaServiceProvider),
  );
});

final foodsForPetProvider =
    StreamProvider.family<List<Food>, String>((ref, petUuid) {
  return ref.watch(foodsRepositoryProvider).watchForPetUuid(petUuid);
});

final activeFoodsForPetProvider =
    StreamProvider.family<List<Food>, String>((ref, petUuid) {
  return ref.watch(foodsRepositoryProvider).watchActiveForPetUuid(petUuid);
});

final foodByUuidProvider =
    StreamProvider.family<Food?, ({String foodUuid, String petUuid})>(
        (ref, args) {
  return ref
      .watch(foodsRepositoryProvider)
      .watchByUuid(args.foodUuid, args.petUuid);
});

final foodPhotosProvider =
    StreamProvider.family<List<FoodPhoto>, String>((ref, foodUuid) {
  return ref.watch(foodsRepositoryProvider).watchPhotos(foodUuid);
});
