import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../insurances/application/insurances_providers.dart';
import '../../pets/application/current_pet_provider.dart';
import '../../pets/domain/pet.dart';
import '../../pets/domain/pet_enums.dart';
import '../../pets/presentation/widgets/age_badge.dart';
import '../../pets/presentation/widgets/pet_avatar.dart';
import '../../vaccinations/application/vaccinations_providers.dart';
import '../../vets/application/vets_providers.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final async = ref.watch(currentPetProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (pet) {
        if (pet == null) {
          return EmptyState(
            icon: Icons.pets_outlined,
            title: l.petsListEmpty,
            actionLabel: l.petsListEmptyAction,
            onAction: () => context.push('/pets/new'),
          );
        }
        return _OverviewContent(pet: pet);
      },
    );
  }
}

class _OverviewContent extends ConsumerWidget {
  const _OverviewContent({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PetAvatar(pet: pet, radius: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                pet.name,
                style: Theme.of(context).textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                AgeBadge(pet: pet),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/emergency'),
                  icon: const Icon(Icons.medical_information_outlined),
                  label: Text(l.emergencyTitle),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionCard(context, children: [
          _row(l.petFieldSpecies, _speciesLabel(l, pet.species)),
          _row(l.petFieldSex, _sexLabel(l, pet.sex, pet.isNeutered)),
          if (pet.breed != null && pet.breed!.isNotEmpty)
            _row(l.petFieldBreed, pet.breed!),
          if (pet.dateOfBirth != null)
            _row(
              l.petFieldDateOfBirth,
              DateFormat.yMd(Localizations.localeOf(context).toString())
                  .format(pet.dateOfBirth!),
            ),
          if (pet.color != null && pet.color!.isNotEmpty)
            _row(l.petFieldColor, pet.color!),
        ]),
        if (pet.chipNumber != null || pet.tassoNumber != null) ...[
          const SizedBox(height: 12),
          _sectionCard(context, children: [
            if (pet.chipNumber != null)
              _row(l.petFieldChipNumber, pet.chipNumber!),
            if (pet.tassoNumber != null)
              _row(l.petFieldTassoNumber, pet.tassoNumber!),
          ]),
        ],
        if (pet.notes != null && pet.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionCard(context, children: [
            _row(l.petFieldNotes, pet.notes!),
          ]),
        ],
        const SizedBox(height: 16),
        _VaccinationStatusTile(petUuid: pet.uuid),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CountTile(
                icon: Icons.medical_services_outlined,
                label: l.overviewVetsTile,
                countProvider: vetCountForPetProvider(pet.uuid),
                onTap: () => context.push('/vets'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CountTile(
                icon: Icons.shield_outlined,
                label: l.overviewInsurancesTile,
                countProvider: insuranceCountForPetProvider(pet.uuid),
                onTap: () => context.push('/insurances'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.actionEdit),
            onTap: () => context.push('/pets/${pet.uuid}/edit'),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(BuildContext context, {required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
      ),
    );
  }

  Widget _row(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: Text(value),
    );
  }

  String _speciesLabel(AppL10n l, Species s) => switch (s) {
        Species.dog => l.speciesDog,
        Species.cat => l.speciesCat,
      };

  String _sexLabel(AppL10n l, Sex s, bool isNeutered) {
    final base = switch (s) {
      Sex.male => l.sexMale,
      Sex.female => l.sexFemale,
    };
    return '$base · ${isNeutered ? l.sexNeutered : l.sexIntact}';
  }
}

class _VaccinationStatusTile extends ConsumerWidget {
  const _VaccinationStatusTile({required this.petUuid});

  final String petUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final async = ref.watch(vaccinationsForPetProvider(petUuid));
    final list = async.valueOrNull ?? const [];
    final withDue = list.where((v) => v.nextDueAt != null).toList()
      ..sort((a, b) => a.nextDueAt!.compareTo(b.nextDueAt!));
    if (withDue.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.vaccines_outlined),
          title: Text(l.overviewVaccinationsTitle),
          subtitle: Text(l.overviewVaccinationsEmpty),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/vaccinations'),
        ),
      );
    }
    final next = withDue.first;
    final overdue = next.isOverdue;
    final scheme = Theme.of(context).colorScheme;
    final daysUntil = next.nextDueAt!.difference(DateTime.now()).inDays;
    return Card(
      color: overdue ? scheme.errorContainer : null,
      child: ListTile(
        leading: Icon(
          Icons.vaccines_outlined,
          color: overdue ? scheme.onErrorContainer : scheme.primary,
        ),
        title: Text(
          next.vaccineName,
          style: TextStyle(
            color: overdue ? scheme.onErrorContainer : null,
          ),
        ),
        subtitle: Text(
          overdue
              ? l.vaccinationOverdueBy(-daysUntil)
              : l.vaccinationDueIn(
                  daysUntil,
                  DateFormat.yMd(Localizations.localeOf(context).toString())
                      .format(next.nextDueAt!),
                ),
          style: TextStyle(
            color: overdue ? scheme.onErrorContainer : null,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: overdue ? scheme.onErrorContainer : null,
        ),
        onTap: () => context.push('/pets/$petUuid/vaccinations/${next.uuid}'),
      ),
    );
  }
}

class _CountTile extends ConsumerWidget {
  const _CountTile({
    required this.icon,
    required this.label,
    required this.countProvider,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ProviderListenable<AsyncValue<int>> countProvider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final async = ref.watch(countProvider);
    final count = async.valueOrNull ?? 0;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                l.overviewCount(count),
                style: TextStyle(color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
