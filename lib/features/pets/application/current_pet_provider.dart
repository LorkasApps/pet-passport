import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../../settings/data/settings_repository.dart';
import '../domain/pet.dart';
import 'pets_providers.dart';

/// The UUID of the pet currently in focus (the "profile").
/// Persisted in the settings table; `null` when no pet is chosen yet
/// or when the previously-chosen pet has been deleted.
final currentPetUuidProvider = StreamProvider<String?>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchRaw(SettingsKeys.currentPetUuid);
});

/// The currently active pet as a domain model. Falls back to the first
/// active pet if [currentPetUuidProvider] returns null or an invalid uuid.
/// Emits `null` when no pets exist.
final currentPetProvider = StreamProvider<Pet?>((ref) {
  final uuidAsync = ref.watch(currentPetUuidProvider);
  final petsAsync = ref.watch(activePetsProvider);

  final uuid = uuidAsync.valueOrNull;
  final pets = petsAsync.valueOrNull;

  if (pets == null) {
    return const Stream<Pet?>.empty();
  }

  if (pets.isEmpty) {
    return Stream.value(null);
  }

  Pet? match;
  if (uuid != null && uuid.isNotEmpty) {
    for (final p in pets) {
      if (p.uuid == uuid) {
        match = p;
        break;
      }
    }
  }
  final chosen = match ?? pets.first;

  // If the stored uuid was stale (deleted pet), heal it in the background.
  if (uuid != chosen.uuid) {
    Future.microtask(() async {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.setRaw(SettingsKeys.currentPetUuid, chosen.uuid);
    });
  }

  // Return a live stream for the chosen pet so edits flow through.
  return ref
      .read(petsRepositoryProvider)
      .watchByUuid(chosen.uuid);
});

Future<void> setCurrentPet(WidgetRef ref, String uuid) async {
  final repo = ref.read(settingsRepositoryProvider);
  await repo.setRaw(SettingsKeys.currentPetUuid, uuid);
}

Future<void> clearCurrentPet(WidgetRef ref) async {
  final repo = ref.read(settingsRepositoryProvider);
  await repo.remove(SettingsKeys.currentPetUuid);
}
