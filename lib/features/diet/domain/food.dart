import 'package:flutter/foundation.dart';

import 'food_enums.dart';

@immutable
class Food {
  const Food({
    required this.uuid,
    required this.petUuid,
    required this.brand,
    required this.name,
    required this.foodType,
    this.portionGrams = 0,
    this.frequencyPerDay = 1,
    this.timesOfDay = const [],
    this.isActive = true,
    required this.startsAt,
    this.endsAt,
    this.remindersEnabled = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uuid;
  final String petUuid;
  final String brand;
  final String name;
  final FoodType foodType;
  final double portionGrams;
  final int frequencyPerDay;
  final List<String> timesOfDay; // ['HH:mm', ...] sorted
  final bool isActive;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool remindersEnabled;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
