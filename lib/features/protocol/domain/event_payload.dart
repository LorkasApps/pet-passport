import 'package:flutter/foundation.dart';

import 'event_enums.dart';

/// Typed payload for an [Event]. Serialized as JSON into
/// `events.payload_json`. The concrete variant is picked based on the
/// event's [EventType] — the DB stores no discriminator inside the JSON
/// itself.
@immutable
sealed class EventPayload {
  const EventPayload();

  Map<String, dynamic> toJson();

  static EventPayload fromJson(EventType type, Map<String, dynamic> json) {
    return switch (type) {
      EventType.weight => WeightPayload.fromJson(json),
      EventType.feeding => FeedingPayload.fromJson(json),
      EventType.symptom => SymptomPayload.fromJson(json),
      EventType.activity => ActivityPayload.fromJson(json),
      EventType.generic => const GenericPayload(),
    };
  }

  static EventPayload empty(EventType type) {
    return switch (type) {
      EventType.weight => const WeightPayload(weightKg: 0),
      EventType.feeding => const FeedingPayload(),
      EventType.symptom =>
        const SymptomPayload(description: '', severity: SymptomSeverity.low),
      EventType.activity =>
        const ActivityPayload(activityType: ActivityType.walk),
      EventType.generic => const GenericPayload(),
    };
  }
}

@immutable
class WeightPayload extends EventPayload {
  const WeightPayload({required this.weightKg});
  final double weightKg;

  @override
  Map<String, dynamic> toJson() => {'weight_kg': weightKg};

  factory WeightPayload.fromJson(Map<String, dynamic> json) => WeightPayload(
        weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      );
}

@immutable
class FeedingPayload extends EventPayload {
  const FeedingPayload({this.foodName, this.amountG, this.meal});
  final String? foodName;
  final int? amountG;
  final FeedingMeal? meal;

  @override
  Map<String, dynamic> toJson() => {
        if (foodName != null) 'food_name': foodName,
        if (amountG != null) 'amount_g': amountG,
        if (meal != null) 'meal': meal!.name,
      };

  factory FeedingPayload.fromJson(Map<String, dynamic> json) => FeedingPayload(
        foodName: json['food_name'] as String?,
        amountG: (json['amount_g'] as num?)?.toInt(),
        meal: _parseMeal(json['meal']),
      );

  static FeedingMeal? _parseMeal(dynamic v) {
    if (v is! String) return null;
    return FeedingMeal.values
        .cast<FeedingMeal?>()
        .firstWhere((m) => m!.name == v, orElse: () => null);
  }
}

@immutable
class SymptomPayload extends EventPayload {
  const SymptomPayload({required this.description, required this.severity});
  final String description;
  final SymptomSeverity severity;

  @override
  Map<String, dynamic> toJson() => {
        'description': description,
        'severity': severity.name,
      };

  factory SymptomPayload.fromJson(Map<String, dynamic> json) => SymptomPayload(
        description: json['description'] as String? ?? '',
        severity: _parseSeverity(json['severity']) ?? SymptomSeverity.low,
      );

  static SymptomSeverity? _parseSeverity(dynamic v) {
    if (v is! String) return null;
    return SymptomSeverity.values
        .cast<SymptomSeverity?>()
        .firstWhere((s) => s!.name == v, orElse: () => null);
  }
}

@immutable
class ActivityPayload extends EventPayload {
  const ActivityPayload({
    required this.activityType,
    this.distanceM,
    this.durationMin,
  });
  final ActivityType activityType;
  final int? distanceM;
  final int? durationMin;

  @override
  Map<String, dynamic> toJson() => {
        'activity_type': activityType.name,
        if (distanceM != null) 'distance_m': distanceM,
        if (durationMin != null) 'duration_min': durationMin,
      };

  factory ActivityPayload.fromJson(Map<String, dynamic> json) =>
      ActivityPayload(
        activityType:
            _parseActivityType(json['activity_type']) ?? ActivityType.walk,
        distanceM: (json['distance_m'] as num?)?.toInt(),
        durationMin: (json['duration_min'] as num?)?.toInt(),
      );

  static ActivityType? _parseActivityType(dynamic v) {
    if (v is! String) return null;
    return ActivityType.values
        .cast<ActivityType?>()
        .firstWhere((a) => a!.name == v, orElse: () => null);
  }
}

@immutable
class GenericPayload extends EventPayload {
  const GenericPayload();

  @override
  Map<String, dynamic> toJson() => const {};
}
