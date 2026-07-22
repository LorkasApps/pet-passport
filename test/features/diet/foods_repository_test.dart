import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/diet/data/foods_repository.dart';
import 'package:pet_passport/features/diet/domain/food_enums.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';

import '../../helpers/database_helper.dart';

void main() {
  group('FoodsRepository', () {
    late PetsRepository pets;
    late FoodsRepository foods;

    setUp(() {
      final db = newInMemoryDatabase();
      pets = PetsRepository(db.petsDao);
      // notifications=null → repo skips scheduling, keeps CRUD tests fast.
      foods = FoodsRepository(db.foodsDao, db.petsDao);
    });

    test('create → watch returns the new food, active section first', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      final activeUuid = await foods.createFood(
        petUuid: petUuid,
        brand: 'Royal',
        name: 'Mini adult',
        foodType: FoodType.dry,
        portionGrams: 80,
        frequencyPerDay: 2,
        timesOfDay: const ['07:30', '18:00'],
        startsAt: DateTime(2026, 1, 1),
      );
      final histUuid = await foods.createFood(
        petUuid: petUuid,
        brand: 'Old',
        name: 'Old kibble',
        foodType: FoodType.dry,
        isActive: false,
        startsAt: DateTime(2025, 1, 1),
      );

      final all = await foods.watchForPetUuid(petUuid).first;
      expect(all, hasLength(2));
      expect(all.first.uuid, activeUuid);
      expect(all.last.uuid, histUuid);

      final active = await foods.watchActiveForPetUuid(petUuid).first;
      expect(active, hasLength(1));
      expect(active.single.uuid, activeUuid);
      expect(active.single.timesOfDay, ['07:30', '18:00']);
    });

    test('update replaces fields', () async {
      final petUuid = await pets.createPet(
        name: 'Kitty',
        species: Species.cat,
        sex: Sex.female,
      );
      final foodUuid = await foods.createFood(
        petUuid: petUuid,
        brand: '',
        name: 'Wet food',
        foodType: FoodType.wet,
        startsAt: DateTime(2026, 1, 1),
      );

      await foods.updateFood(
        uuid: foodUuid,
        brand: 'Whiskas',
        name: 'Wet food',
        foodType: FoodType.wet,
        portionGrams: 85,
        frequencyPerDay: 3,
        timesOfDay: const ['07:00', '12:00', '18:00'],
        isActive: true,
        startsAt: DateTime(2026, 1, 1),
        remindersEnabled: true,
      );

      final updated =
          await foods.getByUuid(foodUuid, petUuid);
      expect(updated, isNotNull);
      expect(updated!.brand, 'Whiskas');
      expect(updated.portionGrams, 85);
      expect(updated.frequencyPerDay, 3);
      expect(updated.timesOfDay, ['07:00', '12:00', '18:00']);
      expect(updated.remindersEnabled, isTrue);
    });

    test('delete removes the row', () async {
      final petUuid = await pets.createPet(
        name: 'Rex',
        species: Species.dog,
        sex: Sex.male,
      );
      final foodUuid = await foods.createFood(
        petUuid: petUuid,
        brand: '',
        name: 'Kibble',
        foodType: FoodType.dry,
        startsAt: DateTime(2026, 1, 1),
      );

      await foods.deleteByUuid(foodUuid);
      expect(await foods.getByUuid(foodUuid, petUuid), isNull);
      final all = await foods.watchForPetUuid(petUuid).first;
      expect(all, isEmpty);
    });
  });
}
