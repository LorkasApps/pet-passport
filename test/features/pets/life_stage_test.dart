import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/pets/domain/life_stage.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';

void main() {
  group('LifeStageCalculator', () {
    final referenceNow = DateTime(2026, 7, 22);

    test('returns null when dob is missing', () {
      final stage = LifeStageCalculator.compute(
        species: Species.dog,
        dateOfBirth: null,
        now: referenceNow,
      );
      expect(stage, isNull);
    });

    test('classifies puppy for young dog', () {
      final dob = DateTime(2026, 1, 1);
      final stage = LifeStageCalculator.compute(
        species: Species.dog,
        dateOfBirth: dob,
        now: referenceNow,
      );
      expect(stage, LifeStage.puppy);
    });

    test('classifies adult for middle-aged dog', () {
      final dob = DateTime(2022, 5, 1);
      final stage = LifeStageCalculator.compute(
        species: Species.dog,
        dateOfBirth: dob,
        now: referenceNow,
      );
      expect(stage, LifeStage.adult);
    });

    test('classifies senior for old dog', () {
      final dob = DateTime(2015, 1, 1);
      final stage = LifeStageCalculator.compute(
        species: Species.dog,
        dateOfBirth: dob,
        now: referenceNow,
      );
      expect(stage, LifeStage.senior);
    });

    test('cat has extended adult phase', () {
      final dob = DateTime(2018, 1, 1); // ~8.5 years — still adult for cat
      final stage = LifeStageCalculator.compute(
        species: Species.cat,
        dateOfBirth: dob,
        now: referenceNow,
      );
      expect(stage, LifeStage.adult);
    });

    test('cat becomes senior after 10 years', () {
      final dob = DateTime(2015, 1, 1);
      final stage = LifeStageCalculator.compute(
        species: Species.cat,
        dateOfBirth: dob,
        now: referenceNow,
      );
      expect(stage, LifeStage.senior);
    });

    test('age in months is exact', () {
      expect(
        LifeStageCalculator.ageInMonths(
          DateTime(2025, 1, 15),
          DateTime(2026, 7, 22),
        ),
        18,
      );
      expect(
        LifeStageCalculator.ageInMonths(
          DateTime(2025, 1, 25),
          DateTime(2026, 1, 20),
        ),
        11,
      );
    });
  });
}
