import 'package:flutter/foundation.dart';

import 'medication_enums.dart';

@immutable
class Medication {
  const Medication({
    required this.uuid,
    required this.petUuid,
    required this.name,
    required this.dosageAmount,
    required this.dosageUnit,
    required this.freqType,
    this.freqInterval = 1,
    this.freqWeekdays = 0,
    this.timesOfDay = const [],
    required this.startsAt,
    this.endsAt,
    this.isActive = true,
    this.notes,
    this.prescribedByVetUuid,
    this.reminderOffsetsMinutes = const [0],
    required this.createdAt,
    required this.updatedAt,
  });

  final String uuid;
  final String petUuid;
  final String name;
  final double dosageAmount;
  final String dosageUnit;
  final FreqType freqType;
  final int freqInterval;
  final int freqWeekdays; // bitmask, Mon=1
  final List<String> timesOfDay; // ['HH:mm', ...] sorted
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final String? notes;
  final String? prescribedByVetUuid;
  final List<int> reminderOffsetsMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
