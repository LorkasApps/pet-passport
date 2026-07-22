import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/pets_providers.dart';
import '../application/timeline_filter.dart';
import '../application/timeline_providers.dart';
import '../domain/timeline_entry.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  late TimelineFilter _filter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filter = TimelineFilter(
      from: DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 90)),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: _filter.from, end: _filter.to),
    );
    if (range == null) return;
    setState(() {
      _filter = _filter.copyWith(
        from: DateTime(range.start.year, range.start.month, range.start.day),
        to: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
      );
    });
  }

  void _toggleKind(TimelineKind k) {
    final next = {..._filter.kinds};
    if (next.contains(k)) {
      next.remove(k);
    } else {
      next.add(k);
    }
    setState(() => _filter = _filter.copyWith(kinds: next));
  }

  void _setPet(String? uuid) {
    setState(() => _filter = _filter.copyWith(
          petUuid: uuid,
          clearPet: uuid == null,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final entriesAsync = ref.watch(timelineEntriesProvider(_filter));
    final petsAsync = ref.watch(activePetsProvider);
    final pets = petsAsync.valueOrNull ?? const [];
    final locale = Localizations.localeOf(context).toString();
    final dayFmt = DateFormat.yMMMEd(locale);
    final rangeFmt = DateFormat.yMd(locale);

    return Scaffold(
      appBar: AppBar(title: Text(l.timelineTitle)),
      body: Column(
        children: [
          _FilterBar(
            filter: _filter,
            pets: pets,
            rangeLabel:
                '${rangeFmt.format(_filter.from)} — ${rangeFmt.format(_filter.to)}',
            onKindToggle: _toggleKind,
            onPetChanged: _setPet,
            onPickRange: _pickDateRange,
            l: l,
          ),
          const Divider(height: 0),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (entries) {
                if (entries.isEmpty) {
                  return EmptyState(
                    icon: Icons.timeline_outlined,
                    title: l.timelineEmptyTitle,
                    message: l.timelineEmptyMessage,
                  );
                }
                return _GroupedList(
                    entries: entries, dayFmt: dayFmt);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.pets,
    required this.rangeLabel,
    required this.onKindToggle,
    required this.onPetChanged,
    required this.onPickRange,
    required this.l,
  });

  final TimelineFilter filter;
  final List<dynamic> pets;
  final String rangeLabel;
  final void Function(TimelineKind) onKindToggle;
  final void Function(String?) onPetChanged;
  final VoidCallback onPickRange;
  final AppL10n l;

  String _kindLabel(TimelineKind k) => switch (k) {
        TimelineKind.event => l.timelineKindEvent,
        TimelineKind.vaccination => l.timelineKindVaccination,
        TimelineKind.medicationIntake => l.timelineKindMedication,
        TimelineKind.appointment => l.timelineKindAppointment,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: filter.petUuid,
                decoration: InputDecoration(
                  labelText: l.timelineFilterPet,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l.timelineFilterAllPets),
                  ),
                  for (final p in pets)
                    DropdownMenuItem<String?>(
                      value: p.uuid as String,
                      child: Text(p.name as String),
                    ),
                ],
                onChanged: onPetChanged,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onPickRange,
              icon: const Icon(Icons.date_range),
              label: Flexible(
                child: Text(
                  rangeLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final k in TimelineKind.values)
                FilterChip(
                  selected: filter.kinds.contains(k),
                  label: Text(_kindLabel(k)),
                  onSelected: (_) => onKindToggle(k),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.entries, required this.dayFmt});

  final List<TimelineEntry> entries;
  final DateFormat dayFmt;

  @override
  Widget build(BuildContext context) {
    // Group by calendar day (local time).
    final children = <Widget>[];
    DateTime? lastDay;
    for (final e in entries) {
      final day = DateTime(e.at.year, e.at.month, e.at.day);
      if (lastDay == null || day != lastDay) {
        children.add(_DayHeader(day: day, dayFmt: dayFmt));
        lastDay = day;
      }
      children.add(_EntryTile(entry: e));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: children,
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.dayFmt});

  final DateTime day;
  final DateFormat dayFmt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        dayFmt.format(day),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final timeFmt = DateFormat.Hm(locale);
    final scheme = Theme.of(context).colorScheme;
    final subtitleParts = <String>[entry.petName];
    if (entry.subtitle != null && entry.subtitle!.trim().isNotEmpty) {
      subtitleParts.add(entry.subtitle!);
    }
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(entry.icon, color: scheme.onSecondaryContainer),
      ),
      title: Text(entry.title),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Text(
        timeFmt.format(entry.at),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => context.push(entry.route),
    );
  }
}
