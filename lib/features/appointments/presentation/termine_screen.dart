import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../medications/application/medications_providers.dart';
import '../../medications/domain/medication.dart';
import '../../pets/application/current_pet_provider.dart';
import '../../vaccinations/application/vaccinations_providers.dart';
import '../../vaccinations/domain/vaccination.dart';
import '../application/appointments_providers.dart';

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
        final apptsAsync =
            ref.watch(upcomingAppointmentsForPetProvider(pet.uuid));
        final vacsAsync = ref.watch(vaccinationsForPetProvider(pet.uuid));
        final medsAsync =
            ref.watch(activeMedicationsForPetProvider(pet.uuid));

        return Scaffold(
          body: ListView(
            children: [
              apptsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  return _Section(
                    title: l.termineSectionAppointments,
                    children: [
                      for (final u in list.take(5))
                        _AppointmentTile(item: u, petUuid: pet.uuid),
                    ],
                  );
                },
              ),
              vacsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (list) {
                  final upcoming = list
                      .where((v) => v.nextDueAt != null)
                      .toList()
                    ..sort((a, b) => a.nextDueAt!.compareTo(b.nextDueAt!));
                  if (upcoming.isEmpty) return const SizedBox.shrink();
                  return _Section(
                    title: l.termineUpcomingVaccinations,
                    children: [
                      for (final v in upcoming.take(5))
                        _VaccinationTile(vaccination: v, petUuid: pet.uuid),
                    ],
                  );
                },
              ),
              medsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (list) {
                  final today = list.where((m) => _dueToday(m)).toList();
                  if (today.isEmpty) return const SizedBox.shrink();
                  return _Section(
                    title: l.termineSectionMedicationsToday,
                    children: [
                      for (final m in today.take(5))
                        _MedicationTodayTile(medication: m, petUuid: pet.uuid),
                    ],
                  );
                },
              ),
              // Empty state combining all three streams.
              _EmptyIfAllEmpty(petUuid: pet.uuid),
              const SizedBox(height: 96),
            ],
          ),
          floatingActionButton: _NewFab(petUuid: pet.uuid),
        );
      },
    );
  }

  bool _dueToday(Medication m) {
    if (!m.isActive) return false;
    if (m.timesOfDay.isEmpty) return false;
    // Cheap heuristic — surfaces active meds with any time-of-day scheduled.
    return true;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  )),
        ),
        ...children,
      ],
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.item, required this.petUuid});
  final UpcomingAppointment item;
  final String petUuid;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final fmt = DateFormat.yMd(locale).add_Hm();
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.event_outlined)),
      title: Text(item.appointment.title),
      subtitle: Text(fmt.format(item.nextOccurrence)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(
          '/pets/$petUuid/appointments/${item.appointment.uuid}'),
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
    final due = vaccination.nextDueAt!;
    final overdue = vaccination.isOverdue;
    final daysUntil = due.difference(DateTime.now()).inDays;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            overdue ? scheme.errorContainer : scheme.secondaryContainer,
        child: Icon(Icons.vaccines_outlined,
            color: overdue
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer),
      ),
      title: Text(vaccination.vaccineName),
      subtitle: Text(overdue
          ? l.vaccinationOverdueBy(-daysUntil)
          : l.vaccinationDueIn(
              daysUntil, DateFormat.yMd(locale).format(due))),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(
          '/pets/$petUuid/vaccinations/${vaccination.uuid}'),
    );
  }
}

class _MedicationTodayTile extends StatelessWidget {
  const _MedicationTodayTile({required this.medication, required this.petUuid});
  final Medication medication;
  final String petUuid;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.medication_outlined)),
      title: Text(medication.name),
      subtitle: Text(medication.timesOfDay.join(' • ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(
          '/pets/$petUuid/medications/${medication.uuid}'),
    );
  }
}

class _NewFab extends ConsumerWidget {
  const _NewFab({required this.petUuid});
  final String petUuid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return PopupMenuButton<String>(
      icon: FloatingActionButton(
        heroTag: 'termine-fab',
        onPressed: null,
        child: const Icon(Icons.add),
      ),
      offset: const Offset(0, -120),
      onSelected: (v) {
        if (v == 'appt') {
          context.push('/pets/$petUuid/appointments/new');
        } else if (v == 'med') {
          context.push('/pets/$petUuid/medications/new');
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'appt', child: Text(l.appointmentNewTitle)),
        PopupMenuItem(value: 'med', child: Text(l.medicationNewTitle)),
      ],
    );
  }
}

class _EmptyIfAllEmpty extends ConsumerWidget {
  const _EmptyIfAllEmpty({required this.petUuid});
  final String petUuid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final appts = ref.watch(upcomingAppointmentsForPetProvider(petUuid));
    final vacs = ref.watch(vaccinationsForPetProvider(petUuid));
    final meds = ref.watch(activeMedicationsForPetProvider(petUuid));
    final allEmpty = (appts.valueOrNull?.isEmpty ?? true) &&
        ((vacs.valueOrNull ?? const [])
            .where((v) => v.nextDueAt != null)
            .isEmpty) &&
        (meds.valueOrNull?.isEmpty ?? true);
    if (!allEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: EmptyState(
        icon: Icons.event_outlined,
        title: l.termineEmptyTitle,
        message: l.termineEmptyMessage,
      ),
    );
  }
}
