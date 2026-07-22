import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../application/insurances_providers.dart';

class InsurancesListScreen extends ConsumerWidget {
  const InsurancesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.insurancesListTitle)),
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
          final async = ref.watch(insurancesForPetProvider(pet.uuid));
          return async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.shield_outlined,
                  title: l.insurancesEmptyTitle,
                  message: l.insurancesEmptyMessage,
                  actionLabel: l.insurancesEmptyAction,
                  onAction: () =>
                      context.push('/pets/${pet.uuid}/insurances/new'),
                );
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  final ins = list[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      child: const Icon(Icons.shield_outlined),
                    ),
                    title: Text(ins.provider),
                    subtitle: ins.policyNumber == null
                        ? null
                        : Text(ins.policyNumber!),
                    trailing: ins.documents.isEmpty
                        ? const Icon(Icons.chevron_right)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.attach_file, size: 18),
                              Text(' ${ins.documents.length}'),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                    onTap: () => context.push(
                      '/pets/${pet.uuid}/insurances/${ins.uuid}',
                    ),
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
                '/pets/${petAsync.value!.uuid}/insurances/new',
              ),
              icon: const Icon(Icons.add),
              label: Text(l.actionAdd),
            ),
    );
  }
}
