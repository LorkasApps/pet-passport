import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/core/notifications/notification_ids.dart';

void main() {
  group('NotificationIds', () {
    test('is deterministic across calls', () {
      final a = NotificationIds.forSlot(entity: 'appt', uuid: 'abc');
      final b = NotificationIds.forSlot(entity: 'appt', uuid: 'abc');
      expect(a, b);
      expect(a & 0x7fffffff, a); // fits in 31 bits, non-negative
    });

    test('collision-free across entity and uuid variants', () {
      final ids = <int>{
        NotificationIds.forSlot(entity: 'appt', uuid: 'a'),
        NotificationIds.forSlot(entity: 'med', uuid: 'a'),
        NotificationIds.forSlot(entity: 'vac', uuid: 'a'),
        NotificationIds.forSlot(entity: 'appt', uuid: 'b'),
        NotificationIds.forSlot(entity: 'appt', uuid: 'a', slot: 'x'),
      };
      expect(ids.length, 5);
    });

    test('slotFor is stable and comparable', () {
      final t = DateTime.utc(2026, 7, 22, 9, 0);
      final s1 = NotificationIds.slotFor(occurrenceStart: t, offsetMinutes: 15);
      final s2 = NotificationIds.slotFor(occurrenceStart: t, offsetMinutes: 15);
      expect(s1, s2);
      final s3 = NotificationIds.slotFor(occurrenceStart: t, offsetMinutes: 60);
      expect(s1 == s3, isFalse);
    });

    test('legacy forVaccination matches forSlot(entity=vac, slot=empty)', () {
      const uuid = 'some-uuid-1234';
      expect(
        NotificationIds.forVaccination(uuid),
        NotificationIds.forSlot(entity: 'vac', uuid: uuid, slot: ''),
      );
    });

    test('forVaccination numeric parity — golden', () {
      // Freeze the historical FNV-1a output for a known UUID so future
      // refactors of the hash cannot silently break scheduled reminders on
      // real devices.
      expect(
        NotificationIds.forVaccination('11111111-2222-3333-4444-555555555555'),
        1493211461,
      );
    });
  });
}
