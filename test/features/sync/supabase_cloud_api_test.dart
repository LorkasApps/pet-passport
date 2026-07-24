import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/sync/data/supabase_cloud_api.dart';

/// The Supabase-backed CloudApi's payload translator is the one piece
/// worth pinning down without a live network. Exception classification
/// depends on real `PostgrestException` / `AuthException` shapes which
/// aren't ergonomically constructible in a unit test — deferred to a
/// smoke test against a real project once the cloud schema lands.
void main() {
  group('toCloudShape', () {
    test('renames camelCase keys to snake_case', () {
      final out = toCloudShape({
        'name': 'Bello',
        'updatedByUserId': 'user-1',
      });
      expect(out.keys.toSet(), {
        'name',
        'updated_by_user_id',
      });
      expect(out['updated_by_user_id'], 'user-1');
    });

    test('renames `uuid` to `id` (cloud PK name)', () {
      final out = toCloudShape({
        'uuid': 'abc-123',
        'name': 'Bello',
      });
      expect(out.containsKey('id'), isTrue);
      expect(out['id'], 'abc-123');
      expect(out.containsKey('uuid'), isFalse,
          reason: 'client field renamed, not duplicated');
    });

    test('converts known datetime keys from millis-int to ISO-8601', () {
      final at = DateTime.utc(2026, 7, 24, 12, 34, 56);
      final out = toCloudShape({
        'uuid': 'abc',
        'updatedAt': at.millisecondsSinceEpoch,
        'createdAt': at.millisecondsSinceEpoch,
      });
      expect(out['updated_at'], at.toIso8601String());
      expect(out['created_at'], at.toIso8601String());
    });

    test('null datetime passes through as null, not the string "null"',
        () {
      final out = toCloudShape({
        'uuid': 'abc',
        'deletedAt': null,
      });
      // Tombstone semantics need a real null on the cloud side.
      expect(out.containsKey('deleted_at'), isTrue);
      expect(out['deleted_at'], isNull);
    });

    test('every top-level table datetime column gets ISO-converted', () {
      // Guards the specific bug that broke foods, insurances, and
      // vaccinations pushes: their datetime columns weren't in
      // `_dateTimeKeys`, so int-millis payloads hit PostgREST and came
      // back as terminal 4xx. If a new datetime column lands on a
      // synced table, this test forces a matching entry.
      final at = DateTime.utc(2026, 7, 24, 12);
      final ms = at.millisecondsSinceEpoch;
      final out = toCloudShape({
        // pets
        'dateOfBirth': ms,
        // events
        'occurredAt': ms,
        // appointments
        'startsAt': ms,
        'recurrenceUntil': ms,
        // medications + foods
        'endsAt': ms,
        // vaccinations
        'administeredAt': ms,
        'nextDueAt': ms,
        // insurances
        'contractStart': ms,
        'contractEnd': ms,
      });
      final iso = at.toIso8601String();
      for (final k in [
        'date_of_birth',
        'occurred_at',
        'starts_at',
        'recurrence_until',
        'ends_at',
        'administered_at',
        'next_due_at',
        'contract_start',
        'contract_end',
      ]) {
        expect(out[k], iso, reason: '$k must be ISO-8601');
      }
    });

    test('non-datetime ints are left alone', () {
      final out = toCloudShape({
        'uuid': 'abc',
        'sizeBytes': 1024,
      });
      // Would be catastrophic if the heuristic mistook this for a
      // timestamp — 1024 ms after epoch is 1970-01-01, unrelated to
      // the actual file size.
      expect(out['size_bytes'], 1024);
    });

    test('booleans and strings survive unchanged', () {
      final out = toCloudShape({
        'isActive': true,
        'name': 'Bello',
        'notes': null,
      });
      expect(out['is_active'], true);
      expect(out['name'], 'Bello');
      expect(out['notes'], isNull);
    });
  });

  group('fromCloudShape', () {
    test('renames `id` back to `uuid` (local PK name)', () {
      final out = fromCloudShape({
        'id': 'abc-123',
        'name': 'Bello',
      });
      expect(out.containsKey('uuid'), isTrue);
      expect(out['uuid'], 'abc-123');
      expect(out.containsKey('id'), isFalse);
    });

    test('snake_case keys turn back into camelCase', () {
      final out = fromCloudShape({
        'name': 'Bello',
        'updated_by_user_id': 'user-1',
      });
      expect(out.keys.toSet(), {'name', 'updatedByUserId'});
      expect(out['updatedByUserId'], 'user-1');
    });

    test('ISO-8601 datetimes turn back into int millis', () {
      final at = DateTime.utc(2026, 7, 24, 12);
      final iso = at.toIso8601String();
      final out = fromCloudShape({
        'updated_at': iso,
        'starts_at': iso,
        'ends_at': null,
      });
      expect(out['updatedAt'], at.millisecondsSinceEpoch);
      expect(out['startsAt'], at.millisecondsSinceEpoch);
      expect(out['endsAt'], isNull);
    });

    test('round-trip: toCloudShape → fromCloudShape is identity', () {
      final at = DateTime.utc(2026, 7, 24, 12);
      final local = {
        'uuid': 'abc-123',
        'name': 'Bello',
        'updatedAt': at.millisecondsSinceEpoch,
        'deletedAt': null,
        'sizeBytes': 1024,
        'isActive': true,
      };
      final roundTripped = fromCloudShape(toCloudShape(local));
      expect(roundTripped, equals(local));
    });
  });

  group('snakeToCamel', () {
    test('single word passes through', () {
      expect(snakeToCamel('name'), 'name');
    });
    test('multiple segments', () {
      expect(snakeToCamel('updated_by_user_id'), 'updatedByUserId');
    });
    test('two-segment', () {
      expect(snakeToCamel('pet_id'), 'petId');
    });
  });

  group('camelToSnake', () {
    test('handles single word', () {
      expect(camelToSnake('name'), 'name');
    });

    test('splits at each uppercase boundary', () {
      expect(camelToSnake('updatedByUserId'), 'updated_by_user_id');
      expect(camelToSnake('vaccinationPassportNumber'),
          'vaccination_passport_number');
    });

    test('leading char stays as-is (already lower)', () {
      expect(camelToSnake('petId'), 'pet_id');
    });
  });
}
