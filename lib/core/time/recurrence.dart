import 'package:flutter/foundation.dart';

import '../../features/appointments/domain/appointment_enums.dart';
import '../../features/appointments/domain/appointment_exception.dart';

/// Immutable recurrence rule. `weekdaysBitmask` uses Mon=bit0 … Sun=bit6
/// (matches Dart's `DateTime.weekday` where Mon=1..Sun=7 via `1 << (wd-1)`).
@immutable
class RecurrenceSpec {
  const RecurrenceSpec({
    required this.freq,
    this.interval = 1,
    this.weekdaysBitmask = 0,
    this.until,
  });

  const RecurrenceSpec.none()
      : freq = RecurrenceFreq.none,
        interval = 1,
        weekdaysBitmask = 0,
        until = null;

  final RecurrenceFreq freq;
  final int interval;
  final int weekdaysBitmask;
  final DateTime? until;

  bool get isRecurring => freq != RecurrenceFreq.none;

  static int weekdayBit(int weekday) => 1 << (weekday - 1);
}

/// Pure occurrence expansion. Returns each occurrence of `spec` starting at
/// `start`, restricted to `[from, to]`. Honors `spec.until` (inclusive),
/// applies `exceptions` (cancellations + overrides), and stops at `limit`
/// occurrences if given.
///
/// Contract:
/// - `none` freq → yields `start` iff it lies in `[from, to]`.
/// - `daily` freq → `start + n*interval days` for n=0,1,…
/// - `weekly` freq → for each week block of size `interval`, iterate the
///   weekdays selected in bitmask. If bitmask is 0, fall back to the weekday
///   of `start`.
/// - `monthly` freq → same day-of-month each `interval` months, clamped to
///   the last valid day of shorter months.
/// - Exceptions with `isCancelled=true` are skipped; overrides replace the
///   occurrence's datetime with `overrideStartsAt`.
///
/// All math is done in the timezone of `start` (naive DateTime arithmetic).
/// Convert to `tz.TZDateTime` only at the scheduling boundary.
Iterable<DateTime> expandRecurrence({
  required RecurrenceSpec spec,
  required DateTime start,
  required DateTime from,
  required DateTime to,
  int? limit,
  List<AppointmentException> exceptions = const [],
}) sync* {
  if (to.isBefore(from)) return;
  final until = spec.until;

  final exceptionByStart = <int, AppointmentException>{
    for (final e in exceptions) e.occurrenceStart.millisecondsSinceEpoch: e,
  };

  int emitted = 0;
  bool inRange(DateTime dt) =>
      !dt.isBefore(from) && !dt.isAfter(to) &&
      (until == null || !dt.isAfter(until));

  DateTime? applyException(DateTime candidate) {
    final ex = exceptionByStart[candidate.millisecondsSinceEpoch];
    if (ex == null) return candidate;
    if (ex.isCancelled) return null;
    return ex.overrideStartsAt ?? candidate;
  }

  bool shouldStop(DateTime candidate) {
    if (until != null && candidate.isAfter(until)) return true;
    if (candidate.isAfter(to)) return true;
    return false;
  }

  switch (spec.freq) {
    case RecurrenceFreq.none:
      final resolved = applyException(start);
      if (resolved != null && inRange(resolved)) yield resolved;
      return;

    case RecurrenceFreq.daily:
      final step = spec.interval < 1 ? 1 : spec.interval;
      var occ = start;
      while (!shouldStop(occ)) {
        final resolved = applyException(occ);
        if (resolved != null && inRange(resolved)) {
          yield resolved;
          emitted++;
          if (limit != null && emitted >= limit) return;
        }
        occ = _addDays(occ, step);
      }
      return;

    case RecurrenceFreq.weekly:
      final step = spec.interval < 1 ? 1 : spec.interval;
      final mask = spec.weekdaysBitmask == 0
          ? RecurrenceSpec.weekdayBit(start.weekday)
          : spec.weekdaysBitmask;
      // Anchor at Monday of `start`'s week (weekday 1..7 → Mon).
      final anchor = _addDays(start, -(start.weekday - 1));
      var weekStart = anchor;
      while (true) {
        for (var wd = 1; wd <= 7; wd++) {
          if ((mask & RecurrenceSpec.weekdayBit(wd)) == 0) continue;
          final dayOnly = _addDays(weekStart, wd - 1);
          final occ = _copyTimeFrom(dayOnly, start);
          if (occ.isBefore(start)) continue;
          if (shouldStop(occ)) return;
          final resolved = applyException(occ);
          if (resolved != null && inRange(resolved)) {
            yield resolved;
            emitted++;
            if (limit != null && emitted >= limit) return;
          }
        }
        weekStart = _addDays(weekStart, 7 * step);
        if (weekStart.isAfter(to)) return;
        if (until != null && weekStart.isAfter(until)) return;
      }

    case RecurrenceFreq.monthly:
      final step = spec.interval < 1 ? 1 : spec.interval;
      final targetDay = start.day;
      var monthIdx = 0;
      while (true) {
        final year = start.year + ((start.month - 1 + monthIdx * step) ~/ 12);
        final month = ((start.month - 1 + monthIdx * step) % 12) + 1;
        final lastDay = _daysInMonth(year, month, utc: start.isUtc);
        final day = targetDay > lastDay ? lastDay : targetDay;
        final occ = _buildDate(
          utc: start.isUtc,
          year: year, month: month, day: day,
          hour: start.hour, minute: start.minute,
          second: start.second, millisecond: start.millisecond,
        );
        if (shouldStop(occ)) return;
        if (!occ.isBefore(start)) {
          final resolved = applyException(occ);
          if (resolved != null && inRange(resolved)) {
            yield resolved;
            emitted++;
            if (limit != null && emitted >= limit) return;
          }
        }
        monthIdx++;
      }
  }
}

DateTime _buildDate({
  required bool utc,
  required int year,
  required int month,
  required int day,
  int hour = 0,
  int minute = 0,
  int second = 0,
  int millisecond = 0,
}) {
  return utc
      ? DateTime.utc(year, month, day, hour, minute, second, millisecond)
      : DateTime(year, month, day, hour, minute, second, millisecond);
}

DateTime _addDays(DateTime dt, int days) {
  return _buildDate(
    utc: dt.isUtc,
    year: dt.year, month: dt.month, day: dt.day + days,
    hour: dt.hour, minute: dt.minute,
    second: dt.second, millisecond: dt.millisecond,
  );
}

DateTime _copyTimeFrom(DateTime dayOnly, DateTime timeSource) {
  return _buildDate(
    utc: dayOnly.isUtc,
    year: dayOnly.year, month: dayOnly.month, day: dayOnly.day,
    hour: timeSource.hour, minute: timeSource.minute,
    second: timeSource.second, millisecond: timeSource.millisecond,
  );
}

int _daysInMonth(int year, int month, {required bool utc}) {
  final firstOfNext = month == 12
      ? _buildDate(utc: utc, year: year + 1, month: 1, day: 1)
      : _buildDate(utc: utc, year: year, month: month + 1, day: 1);
  return firstOfNext.subtract(const Duration(days: 1)).day;
}
