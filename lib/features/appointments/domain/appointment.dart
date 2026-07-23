import 'package:flutter/foundation.dart';

import 'appointment_enums.dart';
import 'appointment_exception.dart';

@immutable
class Appointment {
  const Appointment({
    required this.uuid,
    required this.petUuid,
    required this.type,
    required this.title,
    required this.startsAt,
    required this.durationMinutes,
    this.vetUuid,
    this.contactUuid,
    this.location,
    this.notes,
    this.recurrenceFreq = RecurrenceFreq.none,
    this.recurrenceInterval = 1,
    this.recurrenceWeekdays = 0,
    this.recurrenceUntil,
    this.reminderOffsetsMinutes = const [60],
    this.exceptions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String uuid;
  final String petUuid;
  final AppointmentType type;
  final String title;
  final DateTime startsAt;
  final int durationMinutes;
  final String? vetUuid;
  final String? contactUuid;
  final String? location;
  final String? notes;
  final RecurrenceFreq recurrenceFreq;
  final int recurrenceInterval;
  final int recurrenceWeekdays; // bitmask, Mon=1 (bit0), Sun=64 (bit6)
  final DateTime? recurrenceUntil;
  final List<int> reminderOffsetsMinutes;
  final List<AppointmentException> exceptions;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRecurring => recurrenceFreq != RecurrenceFreq.none;
}
