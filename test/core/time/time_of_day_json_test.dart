import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/core/time/time_of_day_json.dart';

void main() {
  group('TimeOfDayJson', () {
    test('encode sorts + dedupes + rejects malformed', () {
      final out = TimeOfDayJson.encode(['20:00', '08:00', '08:00', 'nope', '25:00']);
      expect(out, '["08:00","20:00"]');
    });

    test('decode returns sorted valid entries', () {
      final list = TimeOfDayJson.decode('["08:00","20:00"]');
      expect(list, ['08:00', '20:00']);
    });

    test('decode handles null + empty + malformed defensively', () {
      expect(TimeOfDayJson.decode(null), isEmpty);
      expect(TimeOfDayJson.decode(''), isEmpty);
      expect(TimeOfDayJson.decode('not json'), isEmpty);
      expect(TimeOfDayJson.decode('{"foo":"bar"}'), isEmpty);
      expect(TimeOfDayJson.decode('["25:00", 42, null, "08:00"]'), ['08:00']);
    });

    test('isValid accepts HH:mm 00-23 / 00-59', () {
      expect(TimeOfDayJson.isValid('00:00'), isTrue);
      expect(TimeOfDayJson.isValid('23:59'), isTrue);
      expect(TimeOfDayJson.isValid('9:00'), isFalse); // must be 2 digits
      expect(TimeOfDayJson.isValid('24:00'), isFalse);
      expect(TimeOfDayJson.isValid('08:60'), isFalse);
    });
  });
}
