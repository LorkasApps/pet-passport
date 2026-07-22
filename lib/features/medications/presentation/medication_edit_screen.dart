import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/time/recurrence.dart';
import '../../../core/widgets/reminder_offset_chips.dart';
import '../../vets/application/vets_providers.dart';
import '../application/medications_providers.dart';
import '../domain/medication.dart';
import '../domain/medication_enums.dart';

class MedicationEditScreen extends ConsumerStatefulWidget {
  const MedicationEditScreen({
    super.key,
    required this.petUuid,
    this.medicationUuid,
  });

  final String petUuid;
  final String? medicationUuid;

  bool get isEdit => medicationUuid != null;

  @override
  ConsumerState<MedicationEditScreen> createState() =>
      _MedicationEditScreenState();
}

class _MedicationEditScreenState extends ConsumerState<MedicationEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dosageAmountCtrl = TextEditingController(text: '0');
  final _dosageUnitCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController(text: '1');

  FreqType _freqType = FreqType.daily;
  int _freqWeekdays = 0;
  List<String> _timesOfDay = const ['08:00'];
  DateTime _startsAt = DateTime.now();
  DateTime? _endsAt;
  bool _isActive = true;
  String? _prescribedByVetUuid;
  List<int> _reminderOffsets = const [0];
  bool _withFood = false;
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageAmountCtrl.dispose();
    _dosageUnitCtrl.dispose();
    _notesCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  void _prefill(Medication m) {
    if (_prefilled) return;
    _prefilled = true;
    _nameCtrl.text = m.name;
    _dosageAmountCtrl.text = m.dosageAmount.toString();
    _dosageUnitCtrl.text = m.dosageUnit;
    _notesCtrl.text = m.notes ?? '';
    _intervalCtrl.text = m.freqInterval.toString();
    _freqType = m.freqType;
    _freqWeekdays = m.freqWeekdays;
    _timesOfDay = m.timesOfDay.isEmpty ? const ['08:00'] : m.timesOfDay;
    _startsAt = m.startsAt;
    _endsAt = m.endsAt;
    _isActive = m.isActive;
    _prescribedByVetUuid = m.prescribedByVetUuid;
    _reminderOffsets = m.reminderOffsetsMinutes.toList();
    _withFood = m.withFood;
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime(_startsAt.year + 20),
    );
    if (picked != null) setState(() => _startsAt = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endsAt ?? _startsAt.add(const Duration(days: 30)),
      firstDate: _startsAt,
      lastDate: DateTime(_startsAt.year + 20),
    );
    if (picked != null) setState(() => _endsAt = picked);
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context, initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    setState(() {
      final next = {..._timesOfDay, '$hh:$mm'}.toList()..sort();
      _timesOfDay = next;
    });
  }

  String? _emptyToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(medicationsRepositoryProvider);
      final dosageAmount = double.tryParse(
          _dosageAmountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
      final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 1;
      if (widget.isEdit) {
        await repo.updateMedication(
          uuid: widget.medicationUuid!,
          name: _nameCtrl.text.trim(),
          dosageAmount: dosageAmount,
          dosageUnit: _dosageUnitCtrl.text.trim(),
          freqType: _freqType,
          freqInterval: interval < 1 ? 1 : interval,
          freqWeekdays: _freqWeekdays,
          timesOfDay: _timesOfDay,
          startsAt: _startsAt,
          endsAt: _endsAt,
          isActive: _isActive,
          notes: _emptyToNull(_notesCtrl.text),
          prescribedByVetUuid: _prescribedByVetUuid,
          reminderOffsetsMinutes: _reminderOffsets,
          withFood: _withFood,
        );
      } else {
        await repo.createMedication(
          petUuid: widget.petUuid,
          name: _nameCtrl.text.trim(),
          dosageAmount: dosageAmount,
          dosageUnit: _dosageUnitCtrl.text.trim(),
          freqType: _freqType,
          freqInterval: interval < 1 ? 1 : interval,
          freqWeekdays: _freqWeekdays,
          timesOfDay: _timesOfDay,
          startsAt: _startsAt,
          endsAt: _endsAt,
          isActive: _isActive,
          notes: _emptyToNull(_notesCtrl.text),
          prescribedByVetUuid: _prescribedByVetUuid,
          reminderOffsetsMinutes: _reminderOffsets,
          withFood: _withFood,
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
    final fmt = DateFormat.yMd(locale);
    final vetsAsync = ref.watch(vetsForPetProvider(widget.petUuid));

    if (widget.isEdit) {
      final medAsync = ref.watch(medicationByUuidProvider(
        (medUuid: widget.medicationUuid!, petUuid: widget.petUuid),
      ));
      medAsync.whenData((m) {
        if (m != null) _prefill(m);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit
            ? l.medicationEditTitle
            : l.medicationNewTitle),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l.medicationNameLabel),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.errorRequired : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _dosageAmountCtrl,
                  decoration: InputDecoration(
                      labelText: l.medicationDosageAmountLabel),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _dosageUnitCtrl,
                  decoration: InputDecoration(
                      labelText: l.medicationDosageUnitLabel),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<FreqType>(
              initialValue: _freqType,
              decoration:
                  InputDecoration(labelText: l.medicationFreqTypeLabel),
              items: [
                DropdownMenuItem(
                    value: FreqType.daily,
                    child: Text(l.medicationFreqDaily)),
                DropdownMenuItem(
                    value: FreqType.weekly,
                    child: Text(l.medicationFreqWeekly)),
                DropdownMenuItem(
                    value: FreqType.intervalDays,
                    child: Text(l.medicationFreqIntervalDays)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _freqType = v);
              },
            ),
            if (_freqType == FreqType.weekly) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: List.generate(7, (i) {
                final weekday = i + 1;
                final bit = RecurrenceSpec.weekdayBit(weekday);
                final on = (_freqWeekdays & bit) != 0;
                return FilterChip(
                  label: Text(_weekdayShort(l, weekday)),
                  selected: on,
                  onSelected: (sel) {
                    setState(() {
                      _freqWeekdays =
                          sel ? _freqWeekdays | bit : _freqWeekdays & ~bit;
                    });
                  },
                );
              })),
            ],
            if (_freqType != FreqType.daily || true) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _intervalCtrl,
                decoration: InputDecoration(
                    labelText: l.medicationFreqIntervalLabel),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 12),
            Text(l.medicationTimesOfDayLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final t in _timesOfDay)
                  InputChip(
                    label: Text(t),
                    onDeleted: () => setState(
                        () => _timesOfDay = List.of(_timesOfDay)..remove(t)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l.medicationAddTimeButton),
                  onPressed: _addTime,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.medicationStartsAtLabel),
              subtitle: Text(fmt.format(_startsAt)),
              trailing: TextButton(
                  onPressed: _pickStart, child: Text(l.actionEdit)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.medicationEndsAtLabel),
              subtitle: Text(_endsAt == null ? l.optionNone : fmt.format(_endsAt!)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                    onPressed: _pickEnd, child: Text(l.actionEdit)),
                if (_endsAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l.actionClear,
                    onPressed: () => setState(() => _endsAt = null),
                  ),
              ]),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.medicationActiveLabel),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.medicationWithFoodLabel),
              subtitle: Text(l.medicationWithFoodHint),
              value: _withFood,
              onChanged: (v) => setState(() => _withFood = v),
            ),
            const SizedBox(height: 12),
            vetsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (vets) {
                if (vets.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<String?>(
                  initialValue: _prescribedByVetUuid,
                  decoration: InputDecoration(
                      labelText: l.medicationPrescribedByLabel),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.optionNone)),
                    for (final v in vets)
                      DropdownMenuItem(value: v.uuid, child: Text(v.name)),
                  ],
                  onChanged: (v) => setState(() => _prescribedByVetUuid = v),
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: l.notesLabel),
              maxLines: 3,
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

  String _weekdayShort(AppL10n l, int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return l.weekdayShortMon;
      case DateTime.tuesday:
        return l.weekdayShortTue;
      case DateTime.wednesday:
        return l.weekdayShortWed;
      case DateTime.thursday:
        return l.weekdayShortThu;
      case DateTime.friday:
        return l.weekdayShortFri;
      case DateTime.saturday:
        return l.weekdayShortSat;
      case DateTime.sunday:
        return l.weekdayShortSun;
      default:
        return '';
    }
  }
}
