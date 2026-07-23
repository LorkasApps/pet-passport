import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/time/recurrence.dart';
import '../../../core/util/maps_launcher.dart';
import '../../contacts/application/contacts_providers.dart';
import '../../contacts/presentation/contacts_list_screen.dart'
    show contactRoleLabel;
import '../../vets/application/vets_providers.dart';
import '../application/appointments_providers.dart';
import '../domain/appointment_enums.dart';

class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.petUuid,
    required this.appointmentUuid,
  });

  final String petUuid;
  final String appointmentUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final fmt = DateFormat.yMd(locale).add_Hm();
    final apptAsync = ref.watch(appointmentByUuidProvider(
      (apptUuid: appointmentUuid, petUuid: petUuid),
    ));
    return Scaffold(
      appBar: AppBar(title: Text(l.appointmentDetailTitle), actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: l.actionEdit,
          onPressed: () => context.push(
              '/pets/$petUuid/appointments/$appointmentUuid/edit'),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l.actionDelete,
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.confirmDeleteTitle),
                content: Text(l.confirmDeleteMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l.actionCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(l.actionDelete),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            await ref
                .read(appointmentsRepositoryProvider)
                .deleteByUuid(appointmentUuid);
            if (context.mounted) context.pop();
          },
        ),
      ]),
      body: apptAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (a) {
          if (a == null) {
            return Center(child: Text(l.notFound));
          }
          final upcoming = expandRecurrence(
            spec: RecurrenceSpec(
              freq: a.recurrenceFreq,
              interval: a.recurrenceInterval,
              weekdaysBitmask: a.recurrenceWeekdays,
              until: a.recurrenceUntil,
            ),
            start: a.startsAt,
            from: DateTime.now(),
            to: DateTime.now().add(const Duration(days: 60)),
            limit: 5,
            exceptions: a.exceptions,
          ).toList();

          // Vet appointments derive their location from the linked vet.
          // Everything else uses the free-text location column.
          final vetAsync = a.vetUuid == null
              ? null
              : ref.watch(vetByUuidProvider(
                  (vetUuid: a.vetUuid!, petUuid: petUuid)));
          final vet = vetAsync?.valueOrNull;
          final contactAsync = a.contactUuid == null
              ? null
              : ref.watch(contactByUuidProvider(
                  (contactUuid: a.contactUuid!, petUuid: petUuid)));
          final contact = contactAsync?.valueOrNull;
          final effectiveLocation = a.type == AppointmentType.vet
              ? vet?.address
              : a.location;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(a.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              _kv(context, l.appointmentStartsAtLabel, fmt.format(a.startsAt)),
              _kv(context, l.appointmentDurationLabel,
                  l.durationMinutesValue(a.durationMinutes)),
              if (vet != null)
                _link(
                  context: context,
                  label: l.appointmentVetLabel,
                  value: vet.name,
                  onTap: () => context.push('/pets/$petUuid/vets/${vet.uuid}'),
                ),
              if (contact != null)
                _link(
                  context: context,
                  label: l.appointmentContactLabel,
                  value: '${contact.name} · '
                      '${contactRoleLabel(l, contact.role)}',
                  onTap: () => context
                      .push('/pets/$petUuid/contacts/${contact.uuid}'),
                ),
              if (effectiveLocation != null && effectiveLocation.isNotEmpty)
                _locationRow(context, l, effectiveLocation),
              if (a.notes != null && a.notes!.isNotEmpty)
                _kv(context, l.notesLabel, a.notes!),
              const SizedBox(height: 16),
              if (a.isRecurring) ...[
                Text(l.upcomingOccurrencesTitle,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (upcoming.isEmpty)
                  Text(l.noUpcomingOccurrences)
                else
                  for (final o in upcoming)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.event, size: 20),
                      title: Text(fmt.format(o)),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _kv(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(key,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _link({
    required BuildContext context,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(
                value,
                style: TextStyle(
                  color: scheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: scheme.primary.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationRow(BuildContext context, AppL10n l, String address) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(l.appointmentLocationLabel,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(address)),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: l.actionOpenInMaps,
            onPressed: () => openInMaps(context, address),
          ),
        ],
      ),
    );
  }
}
