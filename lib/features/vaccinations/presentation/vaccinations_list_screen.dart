import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../application/vaccinations_providers.dart';
import '../domain/vaccination.dart';

class VaccinationsListScreen extends ConsumerWidget {
  const VaccinationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.vaccinationsListTitle)),
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
          final async = ref.watch(vaccinationsForPetProvider(pet.uuid));
          return async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.vaccines_outlined,
                  title: l.vaccinationsEmptyTitle,
                  message: l.vaccinationsEmptyMessage,
                  actionLabel: l.vaccinationsEmptyAction,
                  onAction: () =>
                      context.push('/pets/${pet.uuid}/vaccinations/new'),
                );
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 0),
                itemBuilder: (context, i) =>
                    _VaccinationTile(vaccination: list[i], petUuid: pet.uuid),
              );
            },
          );
        },
      ),
      floatingActionButton: petAsync.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(
                '/pets/${petAsync.value!.uuid}/vaccinations/new',
              ),
              icon: const Icon(Icons.add),
              label: Text(l.actionAdd),
            ),
    );
  }
}

class _VaccinationTile extends StatelessWidget {
  const _VaccinationTile({required this.vaccination, required this.petUuid});

  final Vaccination vaccination;
  final String petUuid;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final overdue = vaccination.isOverdue;
    final due = vaccination.nextDueAt;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            overdue ? scheme.errorContainer : scheme.secondaryContainer,
        child: Icon(
          Icons.vaccines_outlined,
          color: overdue ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
      ),
      title: Text(vaccination.vaccineName),
      subtitle: Text(
        '${l.vaccinationAdministeredOn(
          DateFormat.yMd(locale).format(vaccination.administeredAt),
        )}'
        '${due != null ? '\n${l.vaccinationNextDue(DateFormat.yMd(locale).format(due))}' : ''}',
      ),
      isThreeLine: due != null,
      trailing: overdue
          ? Chip(
              label: Text(l.vaccinationOverdue),
              backgroundColor: scheme.errorContainer,
              labelStyle: TextStyle(color: scheme.onErrorContainer),
              visualDensity: VisualDensity.compact,
            )
          : const Icon(Icons.chevron_right),
      onTap: () => context.push(
        '/pets/$petUuid/vaccinations/${vaccination.uuid}',
      ),
    );
  }
}
