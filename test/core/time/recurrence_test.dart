import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/core/time/recurrence.dart';
import 'package:pet_passport/features/appointments/domain/appointment_enums.dart';
import 'package:pet_passport/features/appointments/domain/appointment_exception.dart';

void main() {
  group('expandRecurrence — none', () {
    test('yields start iff in range', () {
      final start = DateTime.utc(2026, 7, 22, 9, 0);
      final out = expandRecurrence(
        spec: const RecurrenceSpec.none(),
        start: start,
        from: start,
        to: start.add(const Duration(days: 30)),
      ).toList();
      expect(out, [start]);
    });

    test('skips start when before window', () {
      final start = DateTime.utc(2026, 7, 22, 9, 0);
      final out = expandRecurrence(
        spec: const RecurrenceSpec.none(),
        start: start,
        from: start.add(const Duration(days: 1)),
        to: start.add(const Duration(days: 30)),
      ).toList();
      expect(out, isEmpty);
    });
  });

  group('expandRecurrence — daily', () {
    test('interval=1 emits consecutive days', () {
      final start = DateTime.utc(2026, 7, 22, 9, 0);
      final out = expandRecurrence(
        spec: const RecurrenceSpec(freq: RecurrenceFreq.daily, interval: 1),
        start: start,
        from: start,
        to: start.add(const Duration(days: 4)),
      ).toList();
      expect(out.length, 5);
      expect(out.first, start);
      expect(out.last, start.add(const Duration(days: 4)));
    });

    test('interval=3 emits every third day', () {
      final start = DateTime.utc(2026, 7, 22, 9, 0);
      final out = expandRecurrence(
        spec: const RecurrenceSpec(freq: RecurrenceFreq.daily, interval: 3),
        start: start,
        from: start,
        to: start.add(const Duration(days: 10)),
      ).toList();
      expect(out.length, 4); // day 0, 3, 6, 9
      expect(out[1], start.add(const Duration(days: 3)));
      expect(out[3], start.add(const Duration(days: 9)));
    });

    test('limit caps output', () {
      final start = DateTime.utc(2026, 7, 22, 9, 0);
      final out = expandRecurrence(
        spec: const RecurrenceSpec(freq: RecurrenceFreq.daily),
        start: start,
        from: start,
        to: start.add(const Duration(days: 100)),
        limit: 5,
      ).toList();
      expect(out.length, 5);
    });

    test('until is inclusive', () {
      final start = DateTime.utc(2026, 7, 22, 9, 0);
      final until = start.add(const Duration(days: 2));
      final out = expandRecurrence(
        spec: RecurrenceSpec(
          freq: RecurrenceFreq.daily,
          until: until,
        ),
        start: start,
        from: start,
        to: start.add(const Duration(days: 30)),
      ).toList();
      expect(out.length, 3);
      expect(out.last, until);
    });
  });

  group('expandRecurrence — weekly', () {
    test('bitmask Mo=1 Wed=4 yields matching weekdays', () {
      // 2026-07-20 is Monday.
      final start = DateTime.utc(2026, 7, 20, 9, 0);
      final mask = RecurrenceSpec.weekdayBit(DateTime.monday) |
          RecurrenceSpec.weekdayBit(DateTime.wednesday);
      final out = expandRecurrence(
        spec: RecurrenceSpec(
          freq: RecurrenceFreq.weekly,
          weekdaysBitmask: mask,
        ),
        start: start,
        from: start,
        to: start.add(const Duration(days: 13)),
      ).toList();
      expect(out.length, 4); // Mon 20, Wed 22, Mon 27, Wed 29
      expect(out[0].weekday, DateTime.monday);
      expect(out[1].weekday, DateTime.wednesday);
      expect(out[2].weekday, DateTime.monday);
      expect(out[3].weekday, DateTime.wednesday);
    });

    test('empty bitmask falls back to start weekday', () {
      final start = DateTime.utc(2026, 7, 22, 9, 0); // Wed
      final out = expandRecurrence(
        spec: const RecurrenceSpec(freq: RecurrenceFreq.weekly),
        start: start,
        from: start,
        to: start.add(const Duration(days: 21)),
      ).toList();
      expect(out.length, 4);
      for (final o in out) {
        expect(o.weekday, DateTime.wednesday);
      }
    });

    test('interval=2 skips every other week', () {
      final start = DateTime.utc(2026, 7, 20, 9, 0); // Mon
      final out = expandRecurrence(
        spec: RecurrenceSpec(
          freq: RecurrenceFreq.weekly,
          interval: 2,
          weekdaysBitmask: RecurrenceSpec.weekdayBit(DateTime.monday),
        ),
        start: start,
        from: start,
        to: start.add(const Duration(days: 28)),
      ).toList();
      expect(out.length, 3);
      expect(out[1], start.add(const Duration(days: 14)));
      expect(out[2], start.add(const Duration(days: 28)));
    });
  });

  group('expandRecurrence — monthly', () {
    test('same day-of-month next months', () {
      final start = DateTime.utc(2026, 1, 15, 9, 0);
      final out = expandRecurrence(
        spec: const RecurrenceSpec(freq: RecurrenceFreq.monthly),
        start: start,
        from: start,
        to: DateTime.utc(2026, 6, 30),
      ).toList();
      expect(out.length, 6);
      expect(out.map((d) => d.month), [1, 2, 3, 4, 5, 6]);
      expect(out.every((d) => d.day == 15), isTrue);
    });

    test('day 31 clamps to last of shorter months', () {
      final start = DateTime.utc(2026, 1, 31, 9, 0);
      final out = expandRecurrence(
        spec: const RecurrenceSpec(freq: RecurrenceFreq.monthly),
        start: start,
        from: start,
        to: DateTime.utc(2026, 4, 30, 23, 59),
      ).toList();
      expect(out.length, 4);
      expect(out[0].day, 31); // Jan
      expect(out[1].day, 28); // Feb 2026 (non-leap)
      expect(out[1].month, 2);
      expect(out[2].day, 31); // Mar
      expect(out[3].day, 30); // Apr
    });

    test('interval=2 skips a month', () {
      final start = DateTime.utc(2026, 1, 10, 9, 0);
      final out = expandRecurrence(
        spec: const RecurrenceSpec(freq: RecurrenceFreq.monthly, interval: 2),
        start: start,
        from: start,
        to: DateTime.utc(2026, 12, 31),
      ).toList();
      expect(out.map((d) => d.month), [1, 3, 5, 7, 9, 11]);
    });
  });

  group('expandRecurrence — exceptions', () {
    test('cancellation removes occurrence', () {
      final start = DateTime.utc(2026, 7, 22, 9, 0);
      final skip = start.add(const Duration(days: 1));
      final out = expandRecurrence(
        spec: const RecurrenceSpec(freq: RecurrenceFreq.daily),
        start: start,
        from: start,
        to: start.add(const Duration(days: 3)),
        exceptions: [
          AppointmentException(occurrenceStart: skip, isCancelled: true),
        ],
      ).toList();
      expect(out.length, 3);
      expect(out.contains(skip), isFalse);
    });

    test('override replaces occurrence datetime', () {
      final start = DateTime.utc(2026, 7, 22, 9, 0);
      final orig = start.add(const Duration(days: 1));
      final moved = start.add(const Duration(days: 1, hours: 5));
      final out = expandRecurrence(
        spec: const RecurrenceSpec(freq: RecurrenceFreq.daily),
        start: start,
        from: start,
        to: start.add(const Duration(days: 3)),
        exceptions: [
          AppointmentException(
            occurrenceStart: orig,
            isCancelled: false,
            overrideStartsAt: moved,
          ),
        ],
      ).toList();
      expect(out.length, 4);
      expect(out.contains(moved), isTrue);
      expect(out.contains(orig), isFalse);
    });
  });
}
