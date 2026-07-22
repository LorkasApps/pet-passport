import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../application/medications_providers.dart';

class MedicationIntakeHistoryScreen extends ConsumerWidget {
  const MedicationIntakeHistoryScreen({
    super.key,
    required this.petUuid,
    required this.medicationUuid,
  });

  final String petUuid;
  final String medicationUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final fmt = DateFormat.yMd(locale).add_Hm();
    final async = ref.watch(medicationIntakesProvider(medicationUuid));
    return Scaffold(
      appBar: AppBar(title: Text(l.medicationIntakeHistoryTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: l.medicationIntakeHistoryEmpty,
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final it = list[i];
              return Dismissible(
                key: ValueKey(it.uuid),
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete_outline),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => ref
                    .read(medicationsRepositoryProvider)
                    .deleteIntake(it.uuid),
                child: ListTile(
                  leading: Icon(it.skipped
                      ? Icons.remove_circle_outline
                      : Icons.check_circle_outline),
                  title: Text(fmt.format(it.takenAt)),
                  subtitle: it.note == null ? null : Text(it.note!),
                  trailing: it.skipped
                      ? Chip(label: Text(l.medicationIntakeSkippedChip))
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
