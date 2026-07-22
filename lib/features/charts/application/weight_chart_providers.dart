import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../settings/application/settings_providers.dart';

/// Weights for a given pet uuid, oldest first (chart-ready).
final weightsForPetProvider =
    StreamProvider.family<List<PetWeightRow>, String>((ref, petUuid) async* {
  final db = ref.watch(databaseProvider);
  final pet = await db.petsDao.getByUuid(petUuid);
  if (pet == null) {
    yield const [];
    return;
  }
  // Reuse existing DAO stream (returns DESC by measuredAt); reverse for plot.
  yield* db.petsDao.watchWeightsForPet(pet.id).map(
        (rows) => rows.reversed.toList(growable: false),
      );
});
