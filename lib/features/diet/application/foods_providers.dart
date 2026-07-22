import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../data/foods_repository.dart';
import '../domain/food.dart';

final foodsRepositoryProvider = Provider<FoodsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final notif = ref.watch(notificationServiceProvider);
  return FoodsRepository(
    db.foodsDao,
    db.petsDao,
    notifications: notif,
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
