import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../application/events_providers.dart';
import '../domain/event.dart';
import '../domain/event_enums.dart';
import '../domain/event_payload.dart';
import '../domain/event_tag.dart';

class EventEditScreen extends ConsumerStatefulWidget {
  const EventEditScreen({
    super.key,
    required this.petUuid,
    this.eventUuid,
    this.initialType,
  });

  final String petUuid;
  final String? eventUuid;
  final EventType? initialType;

  bool get isEdit => eventUuid != null;

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _foodNameCtrl = TextEditingController();
  final _amountGCtrl = TextEditingController();
  final _symptomDescCtrl = TextEditingController();
  final _distanceMCtrl = TextEditingController();
  final _durationMinCtrl = TextEditingController();

  EventType _type = EventType.generic;
  DateTime _occurredAt = DateTime.now();
  FeedingMeal? _meal;
  SymptomSeverity _severity = SymptomSeverity.low;
  ActivityType _activityType = ActivityType.walk;
  final Set<String> _selectedTagUuids = {};
  bool _prefilled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) _type = widget.initialType!;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _weightCtrl.dispose();
    _foodNameCtrl.dispose();
    _amountGCtrl.dispose();
    _symptomDescCtrl.dispose();
    _distanceMCtrl.dispose();
    _durationMinCtrl.dispose();
    super.dispose();
  }

  void _prefill(Event e) {
    if (_prefilled) return;
    _prefilled = true;
    _type = e.type;
    _occurredAt = e.occurredAt;
    _titleCtrl.text = e.title ?? '';
    _noteCtrl.text = e.note ?? '';
    _selectedTagUuids.addAll(e.tags.map((t) => t.uuid));
    final p = e.payload;
    if (p is WeightPayload) {
      _weightCtrl.text = p.weightKg == 0 ? '' : p.weightKg.toString();
    } else if (p is FeedingPayload) {
      _foodNameCtrl.text = p.foodName ?? '';
      _amountGCtrl.text = p.amountG?.toString() ?? '';
      _meal = p.meal;
    } else if (p is SymptomPayload) {
      _symptomDescCtrl.text = p.description;
      _severity = p.severity;
    } else if (p is ActivityPayload) {
      _activityType = p.activityType;
      _distanceMCtrl.text = p.distanceM?.toString() ?? '';
      _durationMinCtrl.text = p.durationMin?.toString() ?? '';
    }
  }

  String? _emptyToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickOccurredAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 1),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _occurredAt.hour,
        time?.minute ?? _occurredAt.minute,
      );
    });
  }

  EventPayload _buildPayload(AppL10n l) {
    return switch (_type) {
      EventType.weight => WeightPayload(
          weightKg: double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? 0,
        ),
      EventType.feeding => FeedingPayload(
          foodName: _emptyToNull(_foodNameCtrl.text),
          amountG: int.tryParse(_amountGCtrl.text.trim()),
          meal: _meal,
        ),
      EventType.symptom => SymptomPayload(
          description: _symptomDescCtrl.text.trim(),
          severity: _severity,
        ),
      EventType.activity => ActivityPayload(
          activityType: _activityType,
          distanceM: int.tryParse(_distanceMCtrl.text.trim()),
          durationMin: int.tryParse(_durationMinCtrl.text.trim()),
        ),
      EventType.generic => const GenericPayload(),
    };
  }

  Future<void> _save(AppL10n l) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(eventsRepositoryProvider);
      final payload = _buildPayload(l);
      final title = _emptyToNull(_titleCtrl.text);
      final note = _emptyToNull(_noteCtrl.text);

      String eventUuid;
      if (widget.isEdit) {
        eventUuid = widget.eventUuid!;
        await repo.updateEvent(
          uuid: eventUuid,
          type: _type,
          occurredAt: _occurredAt,
          title: title,
          note: note,
          payload: payload,
        );
        // Sync tags: fetch current, add missing, remove removed.
        final current = await repo
            .watchByUuid(eventUuid, widget.petUuid)
            .first;
        final currentTags = current?.tags.map((t) => t.uuid).toSet() ?? {};
        for (final add in _selectedTagUuids.difference(currentTags)) {
          await repo.assignTag(eventUuid: eventUuid, tagUuid: add);
        }
        for (final rm in currentTags.difference(_selectedTagUuids)) {
          await repo.unassignTag(eventUuid: eventUuid, tagUuid: rm);
        }
      } else {
        eventUuid = await repo.createEvent(
          petUuid: widget.petUuid,
          type: _type,
          occurredAt: _occurredAt,
          title: title,
          note: note,
          payload: payload,
        );
        for (final tagUuid in _selectedTagUuids) {
          await repo.assignTag(eventUuid: eventUuid, tagUuid: tagUuid);
        }
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _attachPhoto() async {
    if (!widget.isEdit) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final path = file.path;
    if (path == null) return;
    await ref.read(eventsRepositoryProvider).attachPhoto(
          eventUuid: widget.eventUuid!,
          source: File(path),
          mimeType: _mimeFor(file.extension),
          sizeBytes: file.size,
        );
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

  Future<void> _newTagDialog(AppL10n l) async {
    final ctrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.eventTagNewDialogTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l.eventTagNewDialogLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l.actionSave),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    final tagUuid =
        await ref.read(eventsRepositoryProvider).createTag(label: label);
    setState(() => _selectedTagUuids.add(tagUuid));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final title = widget.isEdit ? l.eventEditEditTitle : l.eventEditNewTitle;

    if (widget.isEdit) {
      final async = ref.watch(eventByUuidProvider(
        (eventUuid: widget.eventUuid!, petUuid: widget.petUuid),
      ));
      return async.when(
        loading: () => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(child: Text('$e')),
        ),
        data: (e) {
          if (e == null) return Scaffold(appBar: AppBar(title: Text(title)));
          _prefill(e);
          return _buildScaffold(context, title, l, e);
        },
      );
    }
    return _buildScaffold(context, title, l, null);
  }

  Widget _buildScaffold(
    BuildContext context,
    String title,
    AppL10n l,
    Event? event,
  ) {
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(l),
            child: Text(l.actionSave),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: _pickOccurredAt,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.eventFieldOccurredAt,
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
                child:
                    Text(DateFormat.yMd(locale).add_Hm().format(_occurredAt)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: l.eventFieldTitle),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            ..._typeFields(l, locale),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              decoration: InputDecoration(labelText: l.eventFieldNote),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _TagSection(
              selectedUuids: _selectedTagUuids,
              onToggle: (uuid) => setState(() {
                if (_selectedTagUuids.contains(uuid)) {
                  _selectedTagUuids.remove(uuid);
                } else {
                  _selectedTagUuids.add(uuid);
                }
              }),
              onNewTag: () => _newTagDialog(l),
            ),
            if (widget.isEdit && event != null) ...[
              const SizedBox(height: 24),
              _PhotoSection(
                event: event,
                onAdd: _attachPhoto,
                onRemove: (uuid) =>
                    ref.read(eventsRepositoryProvider).removePhoto(uuid),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : () => _save(l),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.actionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _typeFields(AppL10n l, String locale) {
    switch (_type) {
      case EventType.weight:
        return [
          TextFormField(
            controller: _weightCtrl,
            decoration: InputDecoration(labelText: l.eventFieldWeightKg),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l.validationRequired;
              final parsed = double.tryParse(v.replaceAll(',', '.'));
              if (parsed == null || parsed <= 0) {
                return l.eventValidationInvalidNumber;
              }
              return null;
            },
          ),
        ];
      case EventType.feeding:
        return [
          TextFormField(
            controller: _foodNameCtrl,
            decoration: InputDecoration(labelText: l.eventFieldFoodName),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountGCtrl,
            decoration: InputDecoration(labelText: l.eventFieldAmountG),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<FeedingMeal?>(
            initialValue: _meal,
            decoration: InputDecoration(labelText: l.eventFieldMeal),
            items: [
              DropdownMenuItem<FeedingMeal?>(
                value: null,
                child: Text('—'),
              ),
              for (final m in FeedingMeal.values)
                DropdownMenuItem<FeedingMeal?>(
                  value: m,
                  child: Text(_mealLabel(l, m)),
                ),
            ],
            onChanged: (v) => setState(() => _meal = v),
          ),
        ];
      case EventType.symptom:
        return [
          TextFormField(
            controller: _symptomDescCtrl,
            decoration:
                InputDecoration(labelText: l.eventFieldSymptomDescription),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l.validationRequired
                : null,
          ),
          const SizedBox(height: 16),
          Text(l.eventFieldSymptomSeverity,
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          SegmentedButton<SymptomSeverity>(
            segments: [
              ButtonSegment(
                value: SymptomSeverity.low,
                label: Text(l.eventSymptomSeverityLow),
              ),
              ButtonSegment(
                value: SymptomSeverity.medium,
                label: Text(l.eventSymptomSeverityMedium),
              ),
              ButtonSegment(
                value: SymptomSeverity.high,
                label: Text(l.eventSymptomSeverityHigh),
              ),
            ],
            selected: {_severity},
            onSelectionChanged: (s) =>
                setState(() => _severity = s.first),
          ),
        ];
      case EventType.activity:
        return [
          DropdownButtonFormField<ActivityType>(
            initialValue: _activityType,
            decoration: InputDecoration(labelText: l.eventFieldActivityType),
            items: [
              for (final t in ActivityType.values)
                DropdownMenuItem(
                  value: t,
                  child: Text(_activityLabel(l, t)),
                ),
            ],
            onChanged: (v) =>
                setState(() => _activityType = v ?? ActivityType.walk),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _distanceMCtrl,
            decoration: InputDecoration(labelText: l.eventFieldDistanceM),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _durationMinCtrl,
            decoration: InputDecoration(labelText: l.eventFieldDurationMin),
            keyboardType: TextInputType.number,
          ),
        ];
      case EventType.generic:
        return const [];
    }
  }
}

String _mealLabel(AppL10n l, FeedingMeal m) => switch (m) {
      FeedingMeal.morning => l.eventFeedingMealMorning,
      FeedingMeal.noon => l.eventFeedingMealNoon,
      FeedingMeal.evening => l.eventFeedingMealEvening,
      FeedingMeal.snack => l.eventFeedingMealSnack,
    };

String _activityLabel(AppL10n l, ActivityType t) => switch (t) {
      ActivityType.walk => l.eventActivityTypeWalk,
      ActivityType.play => l.eventActivityTypePlay,
      ActivityType.training => l.eventActivityTypeTraining,
      ActivityType.other => l.eventActivityTypeOther,
    };

class _TagSection extends ConsumerWidget {
  const _TagSection({
    required this.selectedUuids,
    required this.onToggle,
    required this.onNewTag,
  });

  final Set<String> selectedUuids;
  final ValueChanged<String> onToggle;
  final VoidCallback onNewTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final tagsAsync = ref.watch(allEventTagsProvider);
    final tags = tagsAsync.valueOrNull ?? const <EventTag>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.eventTagsHeader,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: onNewTag,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.eventTagAddNew),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (final tag in tags)
              FilterChip(
                label: Text(tag.label),
                selected: selectedUuids.contains(tag.uuid),
                onSelected: (_) => onToggle(tag.uuid),
              ),
          ],
        ),
      ],
    );
  }
}

class _PhotoSection extends ConsumerWidget {
  const _PhotoSection({
    required this.event,
    required this.onAdd,
    required this.onRemove,
  });

  final Event event;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
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
        if (event.photos.isEmpty)
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in event.photos)
                Chip(
                  avatar: const Icon(Icons.image_outlined, size: 18),
                  label: Text(
                    p.uuid.substring(0, 6),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onDeleted: () => onRemove(p.uuid),
                ),
            ],
          ),
      ],
    );
  }
}
