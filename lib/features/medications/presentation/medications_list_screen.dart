import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../application/medications_providers.dart';
import '../domain/medication.dart';

class MedicationsListScreen extends ConsumerWidget {
  const MedicationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.medicationsListTitle)),
      body: petAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pet) {
          if (pet == null) {
            return EmptyState(
              icon: Icons.pets_outlined, title: l.petsListEmpty,
            );
          }
          final listAsync = ref.watch(medicationsForPetProvider(pet.uuid));
          return listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.medication_outlined,
                  title: l.medicationsEmptyTitle,
                  message: l.medicationsEmptyMessage,
                );
              }
              final active = list.where((m) => m.isActive).toList();
              final inactive = list.where((m) => !m.isActive).toList();
              return ListView(
                children: [
                  if (active.isNotEmpty) ...[
                    _SectionHeader(text: l.medicationActiveSection),
                    for (final m in active)
                      _MedicationTile(medication: m, petUuid: pet.uuid),
                  ],
                  if (inactive.isNotEmpty) ...[
                    _SectionHeader(text: l.medicationInactiveSection),
                    for (final m in inactive)
                      _MedicationTile(medication: m, petUuid: pet.uuid),
                  ],
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: petAsync.valueOrNull == null
          ? null
          : FloatingActionButton(
              onPressed: () => context.push(
                  '/pets/${petAsync.value!.uuid}/medications/new'),
              child: const Icon(Icons.add),
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

class _MedicationTile extends StatelessWidget {
  const _MedicationTile({required this.medication, required this.petUuid});
  final Medication medication;
  final String petUuid;

  @override
  Widget build(BuildContext context) {
    final subtitle = medication.timesOfDay.isEmpty
        ? ''
        : medication.timesOfDay.join(' • ');
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.medication_outlined)),
      title: Text(medication.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(
          '/pets/$petUuid/medications/${medication.uuid}'),
    );
  }
}
