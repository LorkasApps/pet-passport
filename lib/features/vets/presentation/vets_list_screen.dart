import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../application/vets_providers.dart';
import '../domain/vet.dart';

class VetsListScreen extends ConsumerStatefulWidget {
  const VetsListScreen({super.key});

  @override
  ConsumerState<VetsListScreen> createState() => _VetsListScreenState();
}

class _VetsListScreenState extends ConsumerState<VetsListScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.vetsListTitle),
        actions: [
          IconButton(
            icon: Icon(_showArchived
                ? Icons.visibility_off_outlined
                : Icons.archive_outlined),
            tooltip: _showArchived
                ? l.actionHideArchived
                : l.actionShowArchived,
            onPressed: () =>
                setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
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
              final active = vets.where((v) => v.isActive).toList();
              final archived = vets.where((v) => !v.isActive).toList();
              if (active.isEmpty && (!_showArchived || archived.isEmpty)) {
                return EmptyState(
                  icon: Icons.medical_services_outlined,
                  title: l.vetsEmptyTitle,
                  message: l.vetsEmptyMessage,
                  actionLabel: l.vetsEmptyAction,
                  onAction: () => context.push('/pets/${pet.uuid}/vets/new'),
                  secondaryActionLabel: archived.isEmpty
                      ? null
                      : l.emptyShowArchivedAction(archived.length),
                  onSecondaryAction: archived.isEmpty
                      ? null
                      : () => setState(() => _showArchived = true),
                );
              }
              return ListView(
                children: [
                  for (final v in active) _VetTile(vet: v, petUuid: pet.uuid),
                  if (_showArchived && archived.isNotEmpty) ...[
                    _SectionHeader(text: l.vetsArchivedSection),
                    for (final v in archived)
                      _VetTile(vet: v, petUuid: pet.uuid),
                  ],
                ],
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _VetTile extends StatelessWidget {
  const _VetTile({required this.vet, required this.petUuid});
  final Vet vet;
  final String petUuid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: const Icon(Icons.medical_services_outlined),
      ),
      title: Text(vet.name),
      subtitle: (vet.practice == null || vet.practice!.isEmpty)
          ? null
          : Text(vet.practice!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/pets/$petUuid/vets/${vet.uuid}'),
    );
  }
}
