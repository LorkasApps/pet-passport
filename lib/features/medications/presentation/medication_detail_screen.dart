import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../application/medications_providers.dart';

class MedicationDetailScreen extends ConsumerStatefulWidget {
  const MedicationDetailScreen({
    super.key,
    required this.petUuid,
    required this.medicationUuid,
    this.autoLog = false,
  });

  final String petUuid;
  final String medicationUuid;
  final bool autoLog;

  @override
  ConsumerState<MedicationDetailScreen> createState() =>
      _MedicationDetailScreenState();
}

class _MedicationDetailScreenState
    extends ConsumerState<MedicationDetailScreen> {
  bool _autoLogHandled = false;

  Future<void> _log({required bool skipped}) async {
    final repo = ref.read(medicationsRepositoryProvider);
    await repo.logIntake(
      medicationUuid: widget.medicationUuid, skipped: skipped,
    );
    ref.invalidate(adherenceLast7DaysProvider(widget.medicationUuid));
    if (!mounted) return;
    final l = AppL10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.medicationIntakeLoggedSnack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final medAsync = ref.watch(medicationByUuidProvider(
      (medUuid: widget.medicationUuid, petUuid: widget.petUuid),
    ));
    final adherenceAsync =
        ref.watch(adherenceLast7DaysProvider(widget.medicationUuid));

    if (widget.autoLog && !_autoLogHandled) {
      _autoLogHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _log(skipped: false));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.medicationDetailTitle), actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: l.actionEdit,
          onPressed: () => context.push(
              '/pets/${widget.petUuid}/medications/${widget.medicationUuid}/edit'),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l.actionDelete,
          onPressed: () async {
            final ok = await showDialog<bool>(
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
            if (ok != true || !context.mounted) return;
            await ref
                .read(medicationsRepositoryProvider)
                .deleteByUuid(widget.medicationUuid);
            if (context.mounted) context.pop();
          },
        ),
      ]),
      body: medAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (m) {
          if (m == null) return Center(child: Text(l.notFound));
          final dosage = m.dosageAmount <= 0
              ? ''
              : '${m.dosageAmount % 1 == 0
                  ? m.dosageAmount.toStringAsFixed(0)
                  : m.dosageAmount}${m.dosageUnit.isEmpty ? '' : ' ${m.dosageUnit}'}';
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(m.name, style: Theme.of(context).textTheme.headlineSmall),
            if (dosage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(dosage),
              ),
            if (m.timesOfDay.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(m.timesOfDay.join(' • ')),
              ),
            const SizedBox(height: 24),
            Text(l.medicationAdherenceTitle,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            adherenceAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text('$e'),
              data: (v) => Text(l.medicationAdherenceCount(v.taken, v.expected)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _log(skipped: false),
                  icon: const Icon(Icons.check),
                  label: Text(l.medicationLogIntakeButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _log(skipped: true),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: Text(l.medicationLogSkippedButton),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push(
                  '/pets/${widget.petUuid}/medications/${widget.medicationUuid}/intakes'),
              icon: const Icon(Icons.history),
              label: Text(l.medicationIntakeHistoryTitle),
            ),
            if (m.notes != null && m.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l.notesLabel,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(m.notes!),
            ],
          ]);
        },
      ),
    );
  }
}
