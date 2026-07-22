import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../application/current_pet_provider.dart';
import '../application/pets_providers.dart';
import '../domain/pet.dart';
import 'widgets/pet_avatar.dart';

Future<void> showPetSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _PetSwitcherContent(),
  );
}

class _PetSwitcherContent extends ConsumerWidget {
  const _PetSwitcherContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petsAsync = ref.watch(activePetsProvider);
    final currentAsync = ref.watch(currentPetProvider);
    return SafeArea(
      child: petsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(32),
          child: Text('$e'),
        ),
        data: (pets) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    l.switchPetTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            for (final pet in pets)
              _PetTile(
                pet: pet,
                selected: currentAsync.valueOrNull?.uuid == pet.uuid,
              ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l.actionAdd),
              onTap: () {
                Navigator.pop(context);
                context.push('/pets/new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l.moreManagePets),
              onTap: () {
                Navigator.pop(context);
                context.push('/pets');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PetTile extends ConsumerWidget {
  const _PetTile({required this.pet, required this.selected});

  final Pet pet;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: PetAvatar(pet: pet, radius: 20),
      title: Text(pet.name),
      subtitle: (pet.breed == null || pet.breed!.isEmpty)
          ? null
          : Text(pet.breed!),
      trailing: selected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () async {
        await setCurrentPet(ref, pet.uuid);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }
}
