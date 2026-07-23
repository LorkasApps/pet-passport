import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/time/recurrence.dart';
import '../../../core/widgets/recurrence_editor.dart';
import '../../../core/widgets/reminder_offset_chips.dart';
import '../../vets/application/vets_providers.dart';
import '../../vets/domain/vet.dart';
import '../application/appointments_providers.dart';
import '../domain/appointment.dart';
import '../domain/appointment_enums.dart';

class AppointmentEditScreen extends ConsumerStatefulWidget {
  const AppointmentEditScreen({
    super.key,
    required this.petUuid,
    this.appointmentUuid,
  });

  final String petUuid;
  final String? appointmentUuid;

  bool get isEdit => appointmentUuid != null;

  @override
  ConsumerState<AppointmentEditScreen> createState() =>
      _AppointmentEditScreenState();
}

class _AppointmentEditScreenState
    extends ConsumerState<AppointmentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '60');

  AppointmentType _type = AppointmentType.vet;
  DateTime _startsAt = DateTime.now().add(const Duration(hours: 1));
  String? _vetUuid;
  RecurrenceSpec _spec = const RecurrenceSpec.none();
  List<int> _reminderOffsets = const [60];
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  void _prefill(Appointment a) {
    if (_prefilled) return;
    _prefilled = true;
    _type = a.type;
    _titleCtrl.text = a.title;
    _locationCtrl.text = a.location ?? '';
    _notesCtrl.text = a.notes ?? '';
    _durationCtrl.text = a.durationMinutes.toString();
    _startsAt = a.startsAt;
    _vetUuid = a.vetUuid;
    _spec = RecurrenceSpec(
      freq: a.recurrenceFreq,
      interval: a.recurrenceInterval,
      weekdaysBitmask: a.recurrenceWeekdays,
      until: a.recurrenceUntil,
    );
    _reminderOffsets = a.reminderOffsetsMinutes.toList();
  }

  String? _emptyToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(_startsAt.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;
    setState(() => _startsAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute,
        ));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(appointmentsRepositoryProvider);
      final duration = int.tryParse(_durationCtrl.text.trim()) ?? 60;
      if (widget.isEdit) {
        await repo.updateAppointment(
          uuid: widget.appointmentUuid!,
          type: _type,
          title: _titleCtrl.text.trim(),
          startsAt: _startsAt,
          durationMinutes: duration,
          vetUuid: _vetUuid,
          location: _emptyToNull(_locationCtrl.text),
          notes: _emptyToNull(_notesCtrl.text),
          recurrenceFreq: _spec.freq,
          recurrenceInterval: _spec.interval,
          recurrenceWeekdays: _spec.weekdaysBitmask,
          recurrenceUntil: _spec.until,
          reminderOffsetsMinutes: _reminderOffsets,
        );
      } else {
        await repo.createAppointment(
          petUuid: widget.petUuid,
          type: _type,
          title: _titleCtrl.text.trim(),
          startsAt: _startsAt,
          durationMinutes: duration,
          vetUuid: _vetUuid,
          location: _emptyToNull(_locationCtrl.text),
          notes: _emptyToNull(_notesCtrl.text),
          recurrenceFreq: _spec.freq,
          recurrenceInterval: _spec.interval,
          recurrenceWeekdays: _spec.weekdaysBitmask,
          recurrenceUntil: _spec.until,
          reminderOffsetsMinutes: _reminderOffsets,
        );
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final fmt = DateFormat.yMd(locale).add_Hm();
    final vetsAsync = ref.watch(activeVetsForPetProvider(widget.petUuid));
    final selectedArchivedVet = _vetUuid == null
        ? null
        : ref
            .watch(vetByUuidProvider((
              vetUuid: _vetUuid!,
              petUuid: widget.petUuid,
            )))
            .valueOrNull;

    if (widget.isEdit) {
      final apptAsync = ref.watch(appointmentByUuidProvider(
        (apptUuid: widget.appointmentUuid!, petUuid: widget.petUuid),
      ));
      apptAsync.whenData((a) {
        if (a != null) _prefill(a);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit
            ? l.appointmentEditTitle
            : l.appointmentNewTitle),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<AppointmentType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l.appointmentTypeLabel),
              items: [
                for (final t in AppointmentType.values)
                  DropdownMenuItem(value: t, child: Text(_typeLabel(l, t))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: l.appointmentTitleLabel),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.errorRequired : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text(l.appointmentStartsAtLabel),
              subtitle: Text(fmt.format(_startsAt)),
              trailing: TextButton(
                onPressed: _pickStart,
                child: Text(l.actionEdit),
              ),
            ),
            TextFormField(
              controller: _durationCtrl,
              decoration:
                  InputDecoration(labelText: l.appointmentDurationLabel),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            vetsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (vets) {
                final merged = <Vet>[
                  ...vets,
                  if (selectedArchivedVet != null &&
                      !vets.any((v) => v.uuid == selectedArchivedVet.uuid))
                    selectedArchivedVet,
                ];
                if (merged.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<String?>(
                  initialValue: _vetUuid,
                  decoration: InputDecoration(labelText: l.appointmentVetLabel),
                  items: [
                    DropdownMenuItem(
                        value: null, child: Text(l.optionNone)),
                    for (final v in merged)
                      DropdownMenuItem(value: v.uuid, child: Text(v.name)),
                  ],
                  onChanged: (v) => setState(() => _vetUuid = v),
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration:
                  InputDecoration(labelText: l.appointmentLocationLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: l.notesLabel),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Text(l.recurrenceSectionTitle,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            RecurrenceEditor(
              value: _spec,
              onChanged: (s) => setState(() => _spec = s),
            ),
            const SizedBox(height: 24),
            Text(l.remindersSectionTitle,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ReminderOffsetChips(
              value: _reminderOffsets,
              onChanged: (l) => setState(() => _reminderOffsets = l),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(l.actionSave),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(AppL10n l, AppointmentType t) {
    switch (t) {
      case AppointmentType.vet:
        return l.appointmentTypeVet;
      case AppointmentType.grooming:
        return l.appointmentTypeGrooming;
      case AppointmentType.training:
        return l.appointmentTypeTraining;
      case AppointmentType.walk:
        return l.appointmentTypeWalk;
      case AppointmentType.checkup:
        return l.appointmentTypeCheckup;
      case AppointmentType.other:
        return l.appointmentTypeOther;
    }
  }
}
