import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../application/appointments_providers.dart';
import '../domain/appointment.dart';

class AppointmentsListScreen extends ConsumerWidget {
  const AppointmentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.appointmentsListTitle)),
      body: petAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pet) {
          if (pet == null) {
            return EmptyState(
              icon: Icons.pets_outlined, title: l.petsListEmpty,
            );
          }
          final listAsync = ref.watch(appointmentsForPetProvider(pet.uuid));
          return listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.event_note_outlined,
                  title: l.appointmentsEmptyTitle,
                  message: l.appointmentsEmptyMessage,
                );
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) =>
                    _AppointmentTile(appointment: list[i], petUuid: pet.uuid),
              );
            },
          );
        },
      ),
      floatingActionButton: petAsync.valueOrNull == null
          ? null
          : FloatingActionButton(
              onPressed: () => context.push(
                  '/pets/${petAsync.value!.uuid}/appointments/new'),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment, required this.petUuid});
  final Appointment appointment;
  final String petUuid;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final fmt = DateFormat.yMd(locale).add_Hm();
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.event_outlined)),
      title: Text(appointment.title),
      subtitle: Text(fmt.format(appointment.startsAt)
          + (appointment.isRecurring ? ' • ↻' : '')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(
          '/pets/$petUuid/appointments/${appointment.uuid}'),
    );
  }
}
