import '../../features/appointments/domain/appointment.dart';
import '../../features/appointments/domain/appointment_enums.dart';
import '../../features/appointments/domain/appointment_exception.dart';

/// Builds an RFC 5545 VCALENDAR string for a single [Appointment].
///
/// The output is a self-contained ICS payload with a single VEVENT plus:
///   - RRULE for recurring appointments (daily / weekly / monthly)
///   - EXDATE for cancelled instances
///   - Additional VEVENTs with RECURRENCE-ID for shifted instances
///   - VALARM blocks for each reminder offset
///
/// Times are emitted as floating local (`DTSTART:20260728T093000`) so the
/// user's calendar app interprets them in whatever local zone the user's
/// device advertises when the ICS is opened. That matches how the
/// in-app scheduler already treats these DateTimes.
class IcsBuilder {
  const IcsBuilder._();

  /// [locationOverride] is used when the caller resolved the location out
  /// of a linked vet (which the ICS builder does not know about) — e.g.
  /// vet appointments derive their address from `vet.address`.
  static String buildAppointment(
    Appointment appt, {
    String? locationOverride,
  }) {
    final buf = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//LorkasApps//PetPassport//EN')
      ..writeln('CALSCALE:GREGORIAN')
      // METHOD:PUBLISH is what Google Calendar's importer expects on a
      // one-off event share — omitting it made GCal silently reject the
      // file while Gmail happily forwarded it as an attachment.
      ..writeln('METHOD:PUBLISH');
    _writeMainEvent(buf, appt, locationOverride: locationOverride);
    for (final ex in appt.exceptions.where((e) => !e.isCancelled)) {
      _writeExceptionOverride(buf, appt, ex, locationOverride: locationOverride);
    }
    buf.write('END:VCALENDAR');
    // RFC 5545 mandates CRLF line endings. StringBuffer.writeln uses \n
    // on Unix hosts, so normalise on the way out.
    return buf.toString().replaceAll('\n', '\r\n');
  }

  static void _writeMainEvent(
    StringBuffer buf,
    Appointment appt, {
    String? locationOverride,
  }) {
    final end = appt.startsAt.add(Duration(minutes: appt.durationMinutes));
    final dtstamp = _fmtUtc(DateTime.now().toUtc());
    buf
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:${appt.uuid}@pet-passport')
      ..writeln('DTSTAMP:$dtstamp')
      ..writeln('DTSTART:${_fmtLocal(appt.startsAt)}')
      ..writeln('DTEND:${_fmtLocal(end)}')
      ..writeln('SUMMARY:${_escapeText(appt.title)}');
    final location = locationOverride ?? appt.location;
    if (location != null && location.isNotEmpty) {
      buf.writeln('LOCATION:${_escapeText(location)}');
    }
    if (appt.notes != null && appt.notes!.isNotEmpty) {
      buf.writeln('DESCRIPTION:${_escapeText(appt.notes!)}');
    }
    final rrule = _buildRRule(appt);
    if (rrule != null) buf.writeln('RRULE:$rrule');
    final cancelled = appt.exceptions
        .where((e) => e.isCancelled)
        .map((e) => _fmtLocal(e.occurrenceStart))
        .toList();
    if (cancelled.isNotEmpty) {
      buf.writeln('EXDATE:${cancelled.join(',')}');
    }
    for (final offset in appt.reminderOffsetsMinutes) {
      _writeAlarm(buf, offset);
    }
    buf.writeln('END:VEVENT');
  }

  /// Emits a separate VEVENT for a shifted occurrence, referencing the
  /// original instance via RECURRENCE-ID. Calendar apps merge this back
  /// into the recurring series and show the overridden slot in its new
  /// place.
  static void _writeExceptionOverride(
    StringBuffer buf,
    Appointment appt,
    AppointmentException ex, {
    String? locationOverride,
  }) {
    final override = ex.overrideStartsAt;
    if (override == null) return;
    final end = override.add(Duration(minutes: appt.durationMinutes));
    final dtstamp = _fmtUtc(DateTime.now().toUtc());
    buf
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:${appt.uuid}@pet-passport')
      ..writeln('RECURRENCE-ID:${_fmtLocal(ex.occurrenceStart)}')
      ..writeln('DTSTAMP:$dtstamp')
      ..writeln('DTSTART:${_fmtLocal(override)}')
      ..writeln('DTEND:${_fmtLocal(end)}')
      ..writeln('SUMMARY:${_escapeText(appt.title)}');
    final location = locationOverride ?? appt.location;
    if (location != null && location.isNotEmpty) {
      buf.writeln('LOCATION:${_escapeText(location)}');
    }
    buf.writeln('END:VEVENT');
  }

  static void _writeAlarm(StringBuffer buf, int offsetMinutes) {
    buf
      ..writeln('BEGIN:VALARM')
      ..writeln('ACTION:DISPLAY')
      ..writeln('TRIGGER:-PT${offsetMinutes}M')
      ..writeln('DESCRIPTION:Reminder')
      ..writeln('END:VALARM');
  }

  static String? _buildRRule(Appointment a) {
    if (a.recurrenceFreq == RecurrenceFreq.none) return null;
    final parts = <String>[];
    switch (a.recurrenceFreq) {
      case RecurrenceFreq.daily:
        parts.add('FREQ=DAILY');
        break;
      case RecurrenceFreq.weekly:
        parts.add('FREQ=WEEKLY');
        final days = _weekdayBitmaskToIcs(a.recurrenceWeekdays);
        if (days.isNotEmpty) parts.add('BYDAY=${days.join(',')}');
        break;
      case RecurrenceFreq.monthly:
        parts.add('FREQ=MONTHLY');
        break;
      case RecurrenceFreq.none:
        return null;
    }
    if (a.recurrenceInterval > 1) {
      parts.add('INTERVAL=${a.recurrenceInterval}');
    }
    final until = a.recurrenceUntil;
    if (until != null) {
      // RFC 5545 §3.3.10: when DTSTART is a date with local time, UNTIL
      // MUST also be a date with local time. Emitting `UNTIL=…Z` while
      // DTSTART is floating local is exactly the invalid combination
      // Google Calendar rejects.
      parts.add('UNTIL=${_fmtLocal(until)}');
    }
    return parts.join(';');
  }

  /// Recurrence bitmask uses Mon=bit0, ..., Sun=bit6 (per pet-passport
  /// convention). ICS BYDAY tokens are MO/TU/WE/TH/FR/SA/SU.
  static List<String> _weekdayBitmaskToIcs(int bitmask) {
    const codes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    final result = <String>[];
    for (var i = 0; i < 7; i++) {
      if ((bitmask & (1 << i)) != 0) result.add(codes[i]);
    }
    return result;
  }

  static String _fmtLocal(DateTime dt) {
    // Floating local time (no Z, no TZID) — calendar interprets in the
    // opening device's local zone.
    return '${_pad4(dt.year)}${_pad2(dt.month)}${_pad2(dt.day)}'
        'T${_pad2(dt.hour)}${_pad2(dt.minute)}${_pad2(dt.second)}';
  }

  static String _fmtUtc(DateTime dt) {
    final u = dt.isUtc ? dt : dt.toUtc();
    return '${_pad4(u.year)}${_pad2(u.month)}${_pad2(u.day)}'
        'T${_pad2(u.hour)}${_pad2(u.minute)}${_pad2(u.second)}Z';
  }

  static String _pad2(int v) => v.toString().padLeft(2, '0');
  static String _pad4(int v) => v.toString().padLeft(4, '0');

  /// RFC 5545 §3.3.11 — backslash, semicolon and comma need escaping;
  /// literal newlines become the two-char sequence `\n`.
  static String _escapeText(String s) {
    return s
        .replaceAll('\\', r'\\')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', '')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,');
  }
}
