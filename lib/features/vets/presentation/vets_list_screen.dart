import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../application/vets_providers.dart';

class VetsListScreen extends ConsumerWidget {
  const VetsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.vetsListTitle)),
      body: petAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pet) {
          if (pet == null) {
            return EmptyState(
              icon: Icons.pets_outlined,
              title: l.petsListEmpty,
            );
          }
          final vetsAsync = ref.watch(vetsForPetProvider(pet.uuid));
          return vetsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (vets) {
              if (vets.isEmpty) {
                return EmptyState(
                  icon: Icons.medical_services_outlined,
                  title: l.vetsEmptyTitle,
                  message: l.vetsEmptyMessage,
                  actionLabel: l.vetsEmptyAction,
                  onAction: () => context.push('/pets/${pet.uuid}/vets/new'),
                );
              }
              return ListView.separated(
                itemCount: vets.length,
                separatorBuilder: (_, _) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  final v = vets[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      child: const Icon(Icons.medical_services_outlined),
                    ),
                    title: Text(v.name),
                    subtitle: (v.practice == null || v.practice!.isEmpty)
                        ? null
                        : Text(v.practice!),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/pets/${pet.uuid}/vets/${v.uuid}'),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: petAsync.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(
                '/pets/${petAsync.value!.uuid}/vets/new',
              ),
              icon: const Icon(Icons.add),
              label: Text(l.actionAdd),
            ),
    );
  }
}
