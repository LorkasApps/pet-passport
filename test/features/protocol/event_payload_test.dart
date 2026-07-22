import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/protocol/domain/event_enums.dart';
import 'package:pet_passport/features/protocol/domain/event_payload.dart';

void main() {
  group('EventPayload', () {
    // WeightPayload tests
    test('WeightPayload.fromJson parses weight_kg correctly', () {
      final payload = WeightPayload.fromJson({'weight_kg': 12.4});
      expect(payload.weightKg, 12.4);
    });

    test('WeightPayload.fromJson returns 0 when weight_kg is missing', () {
      final payload = WeightPayload.fromJson({});
      expect(payload.weightKg, 0);
    });

    test('WeightPayload.toJson serializes to weight_kg key', () {
      final payload = WeightPayload(weightKg: 12.4);
      final json = payload.toJson();
      expect(json, {'weight_kg': 12.4});
    });

    // FeedingPayload tests
    test('FeedingPayload.fromJson parses all fields correctly', () {
      final payload = FeedingPayload.fromJson({
        'food_name': 'X',
        'amount_g': 150,
        'meal': 'morning',
      });
      expect(payload.foodName, 'X');
      expect(payload.amountG, 150);
      expect(payload.meal, FeedingMeal.morning);
    });

    test('FeedingPayload.toJson omits null fields', () {
      final payload = FeedingPayload(amountG: 150, meal: FeedingMeal.noon);
      final json = payload.toJson();
      expect(json, {
        'amount_g': 150,
        'meal': 'noon',
      });
      expect(json.containsKey('food_name'), false);
    });

    // SymptomPayload tests
    test('SymptomPayload.fromJson parses description and severity', () {
      final payload = SymptomPayload.fromJson({
        'description': 'x',
        'severity': 'high',
      });
      expect(payload.description, 'x');
      expect(payload.severity, SymptomSeverity.high);
    });

    test('SymptomPayload.fromJson returns defaults when fields missing', () {
      final payload = SymptomPayload.fromJson({});
      expect(payload.description, '');
      expect(payload.severity, SymptomSeverity.low);
    });

    // ActivityPayload tests
    test('ActivityPayload.fromJson parses activity_type and distance_m', () {
      final payload = ActivityPayload.fromJson({
        'activity_type': 'walk',
        'distance_m': 2400,
      });
      expect(payload.activityType, ActivityType.walk);
      expect(payload.distanceM, 2400);
    });

    // EventPayload.fromJson factory tests
    test('EventPayload.fromJson returns WeightPayload for EventType.weight', () {
      final payload = EventPayload.fromJson(
        EventType.weight,
        {'weight_kg': 5},
      );
      expect(payload, isA<WeightPayload>());
      expect((payload as WeightPayload).weightKg, 5);
    });

    test('EventPayload.fromJson returns GenericPayload for EventType.generic', () {
      final payload = EventPayload.fromJson(EventType.generic, {});
      expect(payload, isA<GenericPayload>());
      expect(payload.toJson(), isEmpty);
    });
  });
}
