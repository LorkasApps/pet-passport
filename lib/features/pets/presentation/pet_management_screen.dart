import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../households/application/households_providers.dart';
import '../application/current_pet_provider.dart';
import '../application/pets_providers.dart';
import 'widgets/age_badge.dart';
import 'widgets/pet_avatar.dart';

class PetManagementScreen extends ConsumerWidget {
  const PetManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final async = ref.watch(activePetsProvider);
    final currentAsync = ref.watch(currentPetProvider);
    final households = ref.watch(myHouseholdsProvider).valueOrNull ?? const [];
    final householdNames = {for (final h in households) h.id: h.name};
    // The sub-label only carries the household name when membership
    // spans multiple containers — with a single household the label is
    // redundant noise, and the empty (offline) case has nothing to say.
    final showHouseholdInLabel = households.length > 1;
    return Scaffold(
      appBar: AppBar(title: Text(l.petsListTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pets) {
          if (pets.isEmpty) {
            return EmptyState(
              icon: Icons.pets_outlined,
              title: l.petsListEmpty,
              actionLabel: l.petsListEmptyAction,
              onAction: () => context.push('/pets/new'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: pets.length,
            separatorBuilder: (_, _) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final pet = pets[i];
              final isCurrent = currentAsync.valueOrNull?.uuid == pet.uuid;
              final breed = pet.breed?.trim();
              final hasBreed = breed != null && breed.isNotEmpty;
              final householdName = showHouseholdInLabel
                  ? householdNames[pet.householdId]
                  : null;
              String? subtitle;
              if (householdName != null && hasBreed) {
                subtitle = l.petListHouseholdLabel(householdName, breed);
              } else if (householdName != null) {
                subtitle = householdName;
              } else if (hasBreed) {
                subtitle = breed;
              }
              return ListTile(
                leading: PetAvatar(pet: pet, radius: 24),
                title: Text(pet.name),
                subtitle: subtitle == null ? null : Text(subtitle),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AgeBadge(pet: pet),
                    if (isCurrent)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                  ],
                ),
                onTap: () async {
                  await setCurrentPet(ref, pet.uuid);
                  if (context.mounted) context.go('/home');
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pets/new'),
        icon: const Icon(Icons.add),
        label: Text(l.actionAdd),
      ),
    );
  }
}
