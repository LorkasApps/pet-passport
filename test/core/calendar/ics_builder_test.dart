import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/core/calendar/ics_builder.dart';
import 'package:pet_passport/features/appointments/domain/appointment.dart';
import 'package:pet_passport/features/appointments/domain/appointment_enums.dart';
import 'package:pet_passport/features/appointments/domain/appointment_exception.dart';

void main() {
  group('IcsBuilder.buildAppointment', () {
    final baseCreatedAt = DateTime(2026, 7, 1);

    Appointment appt({
      String uuid = 'appt-1',
      String title = 'Vorsorge',
      DateTime? startsAt,
      int durationMinutes = 45,
      String? location,
      String? notes,
      RecurrenceFreq freq = RecurrenceFreq.none,
      int interval = 1,
      int weekdays = 0,
      DateTime? until,
      List<int> reminders = const [60],
      List<AppointmentException> exceptions = const [],
    }) {
      return Appointment(
        uuid: uuid,
        petUuid: 'pet-1',
        type: AppointmentType.vet,
        title: title,
        startsAt: startsAt ?? DateTime(2026, 8, 1, 9, 30),
        durationMinutes: durationMinutes,
        location: location,
        notes: notes,
        recurrenceFreq: freq,
        recurrenceInterval: interval,
        recurrenceWeekdays: weekdays,
        recurrenceUntil: until,
        reminderOffsetsMinutes: reminders,
        exceptions: exceptions,
        createdAt: baseCreatedAt,
        updatedAt: baseCreatedAt,
      );
    }

    test('wraps a single VEVENT with core RFC 5545 headers', () {
      final ics = IcsBuilder.buildAppointment(appt());
      // Line endings must be CRLF for a valid ICS.
      expect(ics.contains('\r\n'), isTrue);
      expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(ics.trim(), endsWith('END:VCALENDAR'));
      expect(ics, contains('VERSION:2.0'));
      // Google Calendar's importer expects METHOD:PUBLISH on shared
      // one-off events; regression-guard it.
      expect(ics, contains('METHOD:PUBLISH'));
      expect(ics, contains('UID:appt-1@pet-passport'));
      expect(ics, contains('DTSTART:20260801T093000'));
      expect(ics, contains('DTEND:20260801T101500'));
      expect(ics, contains('SUMMARY:Vorsorge'));
    });

    test('escapes reserved characters in SUMMARY / DESCRIPTION', () {
      final ics = IcsBuilder.buildAppointment(
        appt(
          title: 'Kontrolle; wichtig',
          notes: 'Line1\nLine2, Komma',
        ),
      );
      expect(ics, contains(r'SUMMARY:Kontrolle\; wichtig'));
      expect(ics, contains(r'DESCRIPTION:Line1\nLine2\, Komma'));
    });

    test('emits a single VALARM per reminder offset', () {
      final ics = IcsBuilder.buildAppointment(
        appt(reminders: const [15, 1440]),
      );
      expect('VALARM'.allMatches(ics).length, 4); // 2 BEGIN + 2 END
      expect(ics, contains('TRIGGER:-PT15M'));
      expect(ics, contains('TRIGGER:-PT1440M'));
    });

    test('maps weekly recurrence to RRULE with BYDAY', () {
      // Mon (bit0) + Wed (bit2) = 0b101 = 5
      final ics = IcsBuilder.buildAppointment(
        appt(
          freq: RecurrenceFreq.weekly,
          weekdays: 5,
          interval: 2,
          // RFC 5545 §3.3.10: DTSTART is floating local, so UNTIL must
          // also be floating local. Using a plain (non-UTC) DateTime
          // here mirrors what the app stores.
          until: DateTime(2027, 1, 1),
        ),
      );
      expect(
        ics,
        contains(
            'RRULE:FREQ=WEEKLY;BYDAY=MO,WE;INTERVAL=2;UNTIL=20270101T000000'),
      );
      // Regression guard: no stray Z suffix on UNTIL.
      expect(ics.contains('UNTIL=20270101T000000Z'), isFalse);
    });

    test('cancelled exceptions become EXDATE; overrides become extra VEVENTs',
        () {
      final ics = IcsBuilder.buildAppointment(
        appt(
          freq: RecurrenceFreq.monthly,
          exceptions: [
            AppointmentException(
              occurrenceStart: DateTime(2026, 9, 1, 9, 30),
              isCancelled: true,
            ),
            AppointmentException(
              occurrenceStart: DateTime(2026, 10, 1, 9, 30),
              isCancelled: false,
              overrideStartsAt: DateTime(2026, 10, 3, 9, 30),
            ),
          ],
        ),
      );
      expect(ics, contains('EXDATE:20260901T093000'));
      // Two VEVENT blocks total (main + override), so four begin/end tokens.
      expect('BEGIN:VEVENT'.allMatches(ics).length, 2);
      expect(
        ics,
        contains('RECURRENCE-ID:20261001T093000\r\nDTSTAMP'),
      );
      expect(ics, contains('DTSTART:20261003T093000'));
    });

    test('locationOverride takes precedence over stored location', () {
      final ics = IcsBuilder.buildAppointment(
        appt(location: 'Freies Feld'),
        locationOverride: 'Vet-Adresse aus Vet.address',
      );
      expect(ics, contains('LOCATION:Vet-Adresse aus Vet.address'));
      expect(ics.contains('Freies Feld'), isFalse);
    });

    test('no LOCATION line when there is nothing to route to', () {
      final ics = IcsBuilder.buildAppointment(appt());
      expect(ics.contains('\r\nLOCATION:'), isFalse);
    });
  });
}
