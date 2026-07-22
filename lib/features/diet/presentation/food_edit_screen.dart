import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../application/foods_providers.dart';
import '../domain/food.dart';
import '../domain/food_enums.dart';

class FoodEditScreen extends ConsumerStatefulWidget {
  const FoodEditScreen({
    super.key,
    required this.petUuid,
    this.foodUuid,
  });

  final String petUuid;
  final String? foodUuid;

  bool get isEdit => foodUuid != null;

  @override
  ConsumerState<FoodEditScreen> createState() => _FoodEditScreenState();
}

class _FoodEditScreenState extends ConsumerState<FoodEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brandCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _portionCtrl = TextEditingController(text: '0');
  final _freqPerDayCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();

  FoodType _foodType = FoodType.dry;
  List<String> _timesOfDay = const ['08:00'];
  DateTime _startsAt = DateTime.now();
  DateTime? _endsAt;
  bool _isActive = true;
  bool _remindersEnabled = false;
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _nameCtrl.dispose();
    _portionCtrl.dispose();
    _freqPerDayCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _prefill(Food f) {
    if (_prefilled) return;
    _prefilled = true;
    _brandCtrl.text = f.brand;
    _nameCtrl.text = f.name;
    _portionCtrl.text = f.portionGrams.toString();
    _freqPerDayCtrl.text = f.frequencyPerDay.toString();
    _notesCtrl.text = f.notes ?? '';
    _foodType = f.foodType;
    _timesOfDay = f.timesOfDay.isEmpty ? const ['08:00'] : f.timesOfDay;
    _startsAt = f.startsAt;
    _endsAt = f.endsAt;
    _isActive = f.isActive;
    _remindersEnabled = f.remindersEnabled;
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
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
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
      final repo = ref.read(foodsRepositoryProvider);
      final portion = double.tryParse(
              _portionCtrl.text.trim().replaceAll(',', '.')) ??
          0;
      final freqPerDay = int.tryParse(_freqPerDayCtrl.text.trim()) ?? 1;
      if (widget.isEdit) {
        await repo.updateFood(
          uuid: widget.foodUuid!,
          brand: _brandCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          foodType: _foodType,
          portionGrams: portion,
          frequencyPerDay: freqPerDay < 1 ? 1 : freqPerDay,
          timesOfDay: _timesOfDay,
          isActive: _isActive,
          startsAt: _startsAt,
          endsAt: _endsAt,
          remindersEnabled: _remindersEnabled,
          notes: _emptyToNull(_notesCtrl.text),
        );
      } else {
        await repo.createFood(
          petUuid: widget.petUuid,
          brand: _brandCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          foodType: _foodType,
          portionGrams: portion,
          frequencyPerDay: freqPerDay < 1 ? 1 : freqPerDay,
          timesOfDay: _timesOfDay,
          isActive: _isActive,
          startsAt: _startsAt,
          endsAt: _endsAt,
          remindersEnabled: _remindersEnabled,
          notes: _emptyToNull(_notesCtrl.text),
        );
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final l = AppL10n.of(context);
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
    if (ok != true || !mounted) return;
    await ref
        .read(foodsRepositoryProvider)
        .deleteByUuid(widget.foodUuid!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final fmt = DateFormat.yMd(locale);

    if (widget.isEdit) {
      final foodAsync = ref.watch(foodByUuidProvider(
        (foodUuid: widget.foodUuid!, petUuid: widget.petUuid),
      ));
      foodAsync.whenData((f) {
        if (f != null) _prefill(f);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? l.foodEditTitle : l.dietNewTitle),
        actions: [
          if (widget.isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l.actionDelete,
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _brandCtrl,
              decoration: InputDecoration(labelText: l.foodBrandLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l.foodNameLabel),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.errorRequired : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FoodType>(
              initialValue: _foodType,
              decoration: InputDecoration(labelText: l.foodTypeLabel),
              items: [
                DropdownMenuItem(value: FoodType.dry, child: Text(l.foodTypeDry)),
                DropdownMenuItem(value: FoodType.wet, child: Text(l.foodTypeWet)),
                DropdownMenuItem(value: FoodType.raw, child: Text(l.foodTypeRaw)),
                DropdownMenuItem(value: FoodType.barf, child: Text(l.foodTypeBarf)),
                DropdownMenuItem(value: FoodType.treat, child: Text(l.foodTypeTreat)),
                DropdownMenuItem(value: FoodType.other, child: Text(l.foodTypeOther)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _foodType = v);
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _portionCtrl,
                  decoration:
                      InputDecoration(labelText: l.foodPortionGramsLabel),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _freqPerDayCtrl,
                  decoration:
                      InputDecoration(labelText: l.foodFrequencyPerDayLabel),
                  keyboardType: TextInputType.number,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(l.foodTimesOfDayLabel,
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
              title: Text(l.foodStartsAtLabel),
              subtitle: Text(fmt.format(_startsAt)),
              trailing: TextButton(
                  onPressed: _pickStart, child: Text(l.actionEdit)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.foodEndsAtLabel),
              subtitle:
                  Text(_endsAt == null ? l.optionNone : fmt.format(_endsAt!)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                    onPressed: _pickEnd, child: Text(l.actionEdit)),
                if (_endsAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _endsAt = null),
                  ),
              ]),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.foodActiveLabel),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.foodRemindersEnabledLabel),
              subtitle: Text(l.foodRemindersEnabledHint),
              value: _remindersEnabled,
              onChanged: (v) => setState(() => _remindersEnabled = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: l.notesLabel),
              maxLines: 3,
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
}
