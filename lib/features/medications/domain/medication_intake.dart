import 'package:flutter/foundation.dart';

@immutable
class MedicationIntake {
  const MedicationIntake({
    required this.uuid,
    required this.medicationUuid,
    required this.takenAt,
    this.skipped = false,
    this.note,
  });

  final String uuid;
  final String medicationUuid;
  final DateTime takenAt;
  final bool skipped;
  final String? note;
}
