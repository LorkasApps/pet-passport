import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';

import '../../helpers/database_helper.dart';

void main() {
  group('PetsRepository', () {
    late PetsRepository repo;

    setUp(() {
      final db = newInMemoryDatabase();
      repo = PetsRepository(db.petsDao);
    });

    test('creates and lists an active pet', () async {
      final uuid = await repo.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
        breed: 'Labrador',
      );
      expect(uuid, isNotEmpty);
      final pets = await repo.watchActivePets().first;
      expect(pets, hasLength(1));
      expect(pets.first.name, 'Bello');
      expect(pets.first.species, Species.dog);
      expect(pets.first.breed, 'Labrador');
    });

    test('soft-deletes a pet and hides it from active list', () async {
      final uuid = await repo.createPet(
        name: 'Mimi',
        species: Species.cat,
        sex: Sex.female,
      );
      await repo.softDelete(uuid);
      final pets = await repo.watchActivePets().first;
      expect(pets, isEmpty);
    });

    test('updates a pet', () async {
      final uuid = await repo.createPet(
        name: 'Rex',
        species: Species.dog,
        sex: Sex.male,
      );
      await repo.updatePet(
        uuid: uuid,
        name: 'Rex II',
        species: Species.dog,
        sex: Sex.male,
        isNeutered: true,
        breed: 'Mischling',
      );
      final pet = await repo.getByUuid(uuid);
      expect(pet, isNotNull);
      expect(pet!.name, 'Rex II');
      expect(pet.sex, Sex.male);
      expect(pet.isNeutered, isTrue);
      expect(pet.breed, 'Mischling');
    });
  });
}
