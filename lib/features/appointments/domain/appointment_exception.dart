import 'package:flutter/foundation.dart';

@immutable
class AppointmentException {
  const AppointmentException({
    required this.occurrenceStart,
    required this.isCancelled,
    this.overrideStartsAt,
  });

  final DateTime occurrenceStart;
  final bool isCancelled;
  final DateTime? overrideStartsAt;
}
