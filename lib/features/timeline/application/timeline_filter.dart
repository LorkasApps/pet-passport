import 'package:flutter/foundation.dart';

import '../domain/timeline_entry.dart';

/// Filter parameters for the cross-pet timeline. `null` on `petUuid` means
/// "all pets"; an empty `kinds` set means "no kinds" (empty result).
@immutable
class TimelineFilter {
  const TimelineFilter({
    this.petUuid,
    this.kinds = const {
      TimelineKind.event,
      TimelineKind.vaccination,
      TimelineKind.medicationIntake,
      TimelineKind.appointment,
    },
    required this.from,
    required this.to,
  });

  final String? petUuid;
  final Set<TimelineKind> kinds;
  final DateTime from;
  final DateTime to;

  TimelineFilter copyWith({
    String? petUuid,
    bool clearPet = false,
    Set<TimelineKind>? kinds,
    DateTime? from,
    DateTime? to,
  }) {
    return TimelineFilter(
      petUuid: clearPet ? null : (petUuid ?? this.petUuid),
      kinds: kinds ?? this.kinds,
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TimelineFilter &&
      other.petUuid == petUuid &&
      other.kinds.length == kinds.length &&
      other.kinds.containsAll(kinds) &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(
        petUuid,
        Object.hashAllUnordered(kinds),
        from,
        to,
      );
}
