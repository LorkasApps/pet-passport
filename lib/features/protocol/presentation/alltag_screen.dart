import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../application/events_providers.dart';
import '../domain/event.dart';
import '../domain/event_enums.dart';
import '../domain/event_payload.dart';

class AlltagScreen extends ConsumerStatefulWidget {
  const AlltagScreen({super.key});

  @override
  ConsumerState<AlltagScreen> createState() => _AlltagScreenState();
}

class _AlltagScreenState extends ConsumerState<AlltagScreen> {
  EventType? _typeFilter;
  int _rangeDays = 30;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return petAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (pet) {
        if (pet == null) {
          return EmptyState(
            icon: Icons.article_outlined,
            title: l.alltagEmptyTitle,
            message: l.alltagEmptyMessage,
          );
        }
        final now = DateTime.now();
        final filter = EventsFilter(
          petUuid: pet.uuid,
          type: _typeFilter,
          from: DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: _rangeDays)),
        );
        final eventsAsync = ref.watch(eventsForPetProvider(filter));
        return Scaffold(
          body: Column(
            children: [
              _FilterRow(
                selected: _typeFilter,
                onChanged: (v) => setState(() => _typeFilter = v),
                rangeDays: _rangeDays,
                onRangeChanged: (d) => setState(() => _rangeDays = d),
              ),
              Expanded(
                child: eventsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (events) {
                    if (events.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l.alltagNoEventsForFilter,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: events.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) =>
                          _EventTile(event: events[i], petUuid: pet.uuid),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: l.alltagAddEventFabTooltip,
            onPressed: () => _pickTypeAndOpenEdit(context, pet.uuid),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _pickTypeAndOpenEdit(
    BuildContext context,
    String petUuid,
  ) async {
    final l = AppL10n.of(context);
    final picked = await showModalBottomSheet<EventType>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                l.eventPickTypeTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final t in EventType.values)
              ListTile(
                leading: Icon(_iconFor(t)),
                title: Text(_labelFor(l, t)),
                onTap: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await context.push('/pets/$petUuid/events/new?type=${picked.name}');
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.onChanged,
    required this.rangeDays,
    required this.onRangeChanged,
  });

  final EventType? selected;
  final ValueChanged<EventType?> onChanged;
  final int rangeDays;
  final ValueChanged<int> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _typeChip(context, null, l.alltagFilterAll),
                for (final t in EventType.values)
                  _typeChip(context, t, _labelFor(l, t)),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.date_range_outlined, size: 18),
              const SizedBox(width: 8),
              Text(l.alltagFilterRangeLabel(rangeDays)),
              const Spacer(),
              for (final d in const [7, 30, 90, 365])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    label: Text('${d}d'),
                    selected: rangeDays == d,
                    onSelected: (_) => onRangeChanged(d),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeChip(BuildContext context, EventType? type, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == type,
        onSelected: (_) => onChanged(type),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.petUuid});

  final Event event;
  final String petUuid;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(_iconFor(event.type), color: scheme.onSecondaryContainer),
      ),
      title: Text(
        event.title?.isNotEmpty == true
            ? event.title!
            : _labelFor(l, event.type),
      ),
      subtitle: Text(
        [
          _payloadSummary(event, locale),
          DateFormat.yMd(locale).add_Hm().format(event.occurredAt),
          if (event.tags.isNotEmpty)
            event.tags.map((t) => '#${t.label}').join(' '),
        ].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => context.push('/pets/$petUuid/events/${event.uuid}'),
    );
  }

  String _payloadSummary(Event e, String locale) {
    final p = e.payload;
    if (p is WeightPayload) {
      return '${NumberFormat('0.0', locale).format(p.weightKg)} kg';
    }
    if (p is FeedingPayload) {
      return [p.foodName, if (p.amountG != null) '${p.amountG} g']
          .whereType<String>()
          .join(' · ');
    }
    if (p is SymptomPayload) {
      return p.description;
    }
    if (p is ActivityPayload) {
      return [
        if (p.distanceM != null) '${p.distanceM} m',
        if (p.durationMin != null) '${p.durationMin} min',
      ].join(' · ');
    }
    return '';
  }
}

IconData _iconFor(EventType t) => switch (t) {
      EventType.weight => Icons.monitor_weight_outlined,
      EventType.feeding => Icons.restaurant_outlined,
      EventType.symptom => Icons.local_hospital_outlined,
      EventType.activity => Icons.directions_walk_outlined,
      EventType.generic => Icons.article_outlined,
    };

String _labelFor(AppL10n l, EventType t) => switch (t) {
      EventType.weight => l.eventTypeWeight,
      EventType.feeding => l.eventTypeFeeding,
      EventType.symptom => l.eventTypeSymptom,
      EventType.activity => l.eventTypeActivity,
      EventType.generic => l.eventTypeGeneric,
    };
