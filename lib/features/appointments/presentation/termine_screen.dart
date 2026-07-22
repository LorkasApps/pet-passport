import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../../vaccinations/application/vaccinations_providers.dart';
import '../../vaccinations/domain/vaccination.dart';

class TermineScreen extends ConsumerWidget {
  const TermineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return petAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (pet) {
        if (pet == null) {
          return EmptyState(
            icon: Icons.pets_outlined,
            title: l.petsListEmpty,
          );
        }
        final vacsAsync = ref.watch(vaccinationsForPetProvider(pet.uuid));
        return vacsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) {
            final upcoming = list
                .where((v) => v.nextDueAt != null)
                .toList()
              ..sort((a, b) => a.nextDueAt!.compareTo(b.nextDueAt!));
            if (upcoming.isEmpty) {
              return EmptyState(
                icon: Icons.event_outlined,
                title: l.termineEmptyTitle,
                message: l.termineEmptyMessage,
                actionLabel: l.vaccinationsListTitle,
                onAction: () => context.push('/vaccinations'),
              );
            }
            return ListView(
              children: [
                _SectionHeader(text: l.termineUpcomingVaccinations),
                for (final v in upcoming)
                  _UpcomingVaccinationTile(vaccination: v, petUuid: pet.uuid),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/vaccinations'),
                    icon: const Icon(Icons.list),
                    label: Text(l.vaccinationsListTitle),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _UpcomingVaccinationTile extends StatelessWidget {
  const _UpcomingVaccinationTile({
    required this.vaccination,
    required this.petUuid,
  });

  final Vaccination vaccination;
  final String petUuid;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final overdue = vaccination.isOverdue;
    final due = vaccination.nextDueAt!;
    final daysUntil =
        due.difference(DateTime.now()).inDays;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            overdue ? scheme.errorContainer : scheme.secondaryContainer,
        child: Icon(
          Icons.vaccines_outlined,
          color: overdue
              ? scheme.onErrorContainer
              : scheme.onSecondaryContainer,
        ),
      ),
      title: Text(vaccination.vaccineName),
      subtitle: Text(
        overdue
            ? l.vaccinationOverdueBy(-daysUntil)
            : l.vaccinationDueIn(daysUntil,
                DateFormat.yMd(locale).format(due)),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(
          '/pets/$petUuid/vaccinations/${vaccination.uuid}'),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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
