import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/rename_dialog.dart';
import '../../pets/application/pets_providers.dart';
import '../application/foods_providers.dart';
import '../domain/food.dart';
import '../domain/food_enums.dart';
import '../domain/food_photo.dart';

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
  // Files picked before the food has a uuid — flushed in _save() after
  // createFood() returns. Only used on new entries; edit mode attaches
  // straight through the repository.
  final List<_PendingPhoto> _pendingPhotos = [];
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
      String foodUuid;
      if (widget.isEdit) {
        foodUuid = widget.foodUuid!;
        await repo.updateFood(
          uuid: foodUuid,
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
        foodUuid = await repo.createFood(
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
        for (final p in _pendingPhotos) {
          await repo.attachPhoto(
            foodUuid: foodUuid,
            source: p.file,
            mimeType: p.mimeType,
            originalFilename: p.displayName,
            sizeBytes: p.sizeBytes,
          );
        }
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

  Future<void> _renameSavedPhoto(FoodPhoto photo) async {
    final result = await showAttachmentRenameDialog(
      context: context,
      initialTitle: photo.title,
      subtitle: photo.originalFilename,
    );
    if (result == null) return;
    await ref
        .read(foodsRepositoryProvider)
        .renamePhoto(photo.uuid, result);
  }

  Future<void> _attachPhoto() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final path = file.path;
    if (path == null) return;
    final mime = _mimeFor(file.extension);
    if (widget.isEdit) {
      await ref.read(foodsRepositoryProvider).attachPhoto(
            foodUuid: widget.foodUuid!,
            source: File(path),
            mimeType: mime,
            originalFilename: file.name,
            sizeBytes: file.size,
          );
    } else {
      setState(() => _pendingPhotos.add(_PendingPhoto(
            file: File(path),
            displayName: file.name,
            mimeType: mime,
            sizeBytes: file.size,
          )));
    }
  }

  Future<void> _openPhoto(String relativePath) async {
    final absolute = await ref.read(mediaServiceProvider).resolve(relativePath);
    final result = await OpenFilex.open(absolute);
    if (result.type != ResultType.done && mounted) {
      final l = AppL10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.launchFailed)),
      );
    }
  }

  String _mimeFor(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
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
                    tooltip: l.actionClear,
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
            const SizedBox(height: 24),
            _PhotoSection(
              savedPhotos: widget.isEdit
                  ? (ref
                          .watch(foodPhotosProvider(widget.foodUuid!))
                          .valueOrNull ??
                      const [])
                  : const [],
              pending: _pendingPhotos,
              onAdd: _attachPhoto,
              onOpenSaved: _openPhoto,
              onRenameSaved: _renameSavedPhoto,
              onRemoveSaved: (uuid) =>
                  ref.read(foodsRepositoryProvider).removePhoto(uuid),
              onRemovePending: (i) =>
                  setState(() => _pendingPhotos.removeAt(i)),
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

class _PendingPhoto {
  const _PendingPhoto({
    required this.file,
    required this.displayName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final File file;
  final String displayName;
  final String mimeType;
  final int sizeBytes;
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.savedPhotos,
    required this.pending,
    required this.onAdd,
    required this.onOpenSaved,
    required this.onRenameSaved,
    required this.onRemoveSaved,
    required this.onRemovePending,
  });

  final List<FoodPhoto> savedPhotos;
  final List<_PendingPhoto> pending;
  final VoidCallback onAdd;
  final ValueChanged<String> onOpenSaved;
  final ValueChanged<FoodPhoto> onRenameSaved;
  final ValueChanged<String> onRemoveSaved;
  final ValueChanged<int> onRemovePending;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final chips = <Widget>[
      for (final p in savedPhotos)
        // Tap chip → open the file. Long-press → rename. X → remove.
        GestureDetector(
          onLongPress: () => onRenameSaved(p),
          child: InputChip(
            avatar: const Icon(Icons.image_outlined, size: 18),
            label: Text(
              p.displayName(),
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => onOpenSaved(p.filePath),
            onDeleted: () => onRemoveSaved(p.uuid),
            deleteIcon: const Icon(Icons.close, size: 18),
          ),
        ),
      for (var i = 0; i < pending.length; i++)
        Chip(
          avatar: const Icon(Icons.hourglass_top_outlined, size: 18),
          label: Text(
            pending[i].displayName,
            style: const TextStyle(fontSize: 12),
          ),
          onDeleted: () => onRemovePending(i),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.eventPhotosHeader,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(l.eventPhotoAdd),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (chips.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '—',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}
