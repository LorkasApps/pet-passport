import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../pets/application/pets_providers.dart';
import '../application/events_providers.dart';
import '../domain/event.dart';
import '../domain/event_enums.dart';
import '../domain/event_payload.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({
    super.key,
    required this.petUuid,
    required this.eventUuid,
  });

  final String petUuid;
  final String eventUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final async = ref.watch(eventByUuidProvider(
      (eventUuid: eventUuid, petUuid: petUuid),
    ));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (e) {
        if (e == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l.confirmDeleteMessage)),
          );
        }
        return _buildBody(context, ref, e, l);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    Event event,
    AppL10n l,
  ) {
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final title = event.title?.isNotEmpty == true
        ? event.title!
        : _labelFor(l, event.type);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l.actionEdit,
            onPressed: () =>
                context.push('/pets/$petUuid/events/$eventUuid/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l.actionDelete,
            onPressed: () => _confirmDelete(context, ref, l),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: Icon(
                _iconFor(event.type),
                color: scheme.onSecondaryContainer,
              ),
            ),
            title: Text(_labelFor(l, event.type)),
            subtitle: Text(
              DateFormat.yMd(locale).add_Hm().format(event.occurredAt),
            ),
          ),
          const Divider(),
          _payloadCard(context, event, locale, l),
          if (event.note?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.eventFieldNote,
                          style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Text(event.note!),
                    ],
                  ),
                ),
              ),
            ),
          if (event.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l.eventTagsHeader,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final t in event.tags) Chip(label: Text(t.label)),
              ],
            ),
          ],
          if (event.photos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l.eventPhotosHeader,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in event.photos)
                  ActionChip(
                    avatar: const Icon(Icons.image_outlined, size: 18),
                    label: Text(p.uuid.substring(0, 6)),
                    onPressed: () => _openPhoto(context, ref, p.filePath, l),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _payloadCard(
    BuildContext context,
    Event event,
    String locale,
    AppL10n l,
  ) {
    final p = event.payload;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Text(value,
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        );
    List<Widget> body;
    if (p is WeightPayload) {
      body = [
        row(l.eventFieldWeightKg,
            NumberFormat('0.0', locale).format(p.weightKg)),
      ];
    } else if (p is FeedingPayload) {
      body = [
        if (p.foodName != null) row(l.eventFieldFoodName, p.foodName!),
        if (p.amountG != null) row(l.eventFieldAmountG, '${p.amountG} g'),
        if (p.meal != null) row(l.eventFieldMeal, _mealLabel(l, p.meal!)),
      ];
    } else if (p is SymptomPayload) {
      body = [
        row(l.eventFieldSymptomDescription, p.description),
        row(l.eventFieldSymptomSeverity, _severityLabel(l, p.severity)),
      ];
    } else if (p is ActivityPayload) {
      body = [
        row(l.eventFieldActivityType, _activityLabel(l, p.activityType)),
        if (p.distanceM != null)
          row(l.eventFieldDistanceM, '${p.distanceM} m'),
        if (p.durationMin != null)
          row(l.eventFieldDurationMin, '${p.durationMin} min'),
      ];
    } else {
      body = const [];
    }
    if (body.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body),
      ),
    );
  }

  Future<void> _openPhoto(
    BuildContext context,
    WidgetRef ref,
    String relativePath,
    AppL10n l,
  ) async {
    final absolute =
        await ref.read(mediaServiceProvider).resolve(relativePath);
    final result = await OpenFilex.open(absolute);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.launchFailed)));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppL10n l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.eventDeleteConfirmTitle),
        content: Text(l.eventDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(eventsRepositoryProvider).deleteByUuid(eventUuid);
    if (context.mounted) context.pop();
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

String _mealLabel(AppL10n l, FeedingMeal m) => switch (m) {
      FeedingMeal.morning => l.eventFeedingMealMorning,
      FeedingMeal.noon => l.eventFeedingMealNoon,
      FeedingMeal.evening => l.eventFeedingMealEvening,
      FeedingMeal.snack => l.eventFeedingMealSnack,
    };

String _severityLabel(AppL10n l, SymptomSeverity s) => switch (s) {
      SymptomSeverity.low => l.eventSymptomSeverityLow,
      SymptomSeverity.medium => l.eventSymptomSeverityMedium,
      SymptomSeverity.high => l.eventSymptomSeverityHigh,
    };

String _activityLabel(AppL10n l, ActivityType t) => switch (t) {
      ActivityType.walk => l.eventActivityTypeWalk,
      ActivityType.play => l.eventActivityTypePlay,
      ActivityType.training => l.eventActivityTypeTraining,
      ActivityType.other => l.eventActivityTypeOther,
    };
