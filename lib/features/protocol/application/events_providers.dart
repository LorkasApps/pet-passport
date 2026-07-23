import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pets/application/pets_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../sync/application/sync_providers.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import '../domain/event_enums.dart';
import '../domain/event_tag.dart';

@immutable
class EventsFilter {
  const EventsFilter({
    required this.petUuid,
    this.type,
    this.from,
    this.to,
  });

  final String petUuid;
  final EventType? type;
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventsFilter &&
          other.petUuid == petUuid &&
          other.type == type &&
          other.from == from &&
          other.to == to);

  @override
  int get hashCode => Object.hash(petUuid, type, from, to);
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final media = ref.watch(mediaServiceProvider);
  final outbox = ref.watch(syncOutboxProvider);
  return EventsRepository(db, db.eventsDao, db.petsDao, media, outbox: outbox);
});

final eventsForPetProvider =
    StreamProvider.family<List<Event>, EventsFilter>((ref, filter) {
  return ref.watch(eventsRepositoryProvider).watchForPetUuid(
        filter.petUuid,
        typeFilter: filter.type,
        from: filter.from,
        to: filter.to,
      );
});

final eventByUuidProvider = StreamProvider.family<Event?,
    ({String eventUuid, String petUuid})>((ref, args) {
  return ref
      .watch(eventsRepositoryProvider)
      .watchByUuid(args.eventUuid, args.petUuid);
});

final allEventTagsProvider = StreamProvider<List<EventTag>>((ref) {
  return ref.watch(eventsRepositoryProvider).watchAllTags();
});
