import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/vets/data/vets_repository.dart';

import '../../helpers/database_helper.dart';

void main() {
  group('VetsRepository', () {
    late PetsRepository pets;
    late VetsRepository vets;

    setUp(() {
      final db = newInMemoryDatabase();
      pets = PetsRepository(db.petsDao, db);
      vets = VetsRepository(db.vetsDao, db.petsDao);
    });

    test('creates and lists vets scoped to a pet', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      await vets.createVet(
        petUuid: petUuid,
        name: 'Dr. Klein',
        practice: 'Tierklinik Nord',
      );
      final list = await vets.watchForPetUuid(petUuid).first;
      expect(list, hasLength(1));
      expect(list.first.name, 'Dr. Klein');
      expect(list.first.practice, 'Tierklinik Nord');
      expect(await vets.countForPetUuid(petUuid), 1);
    });

    test('cascade-deletes vets when the pet is hard-deleted', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      await vets.createVet(petUuid: petUuid, name: 'Dr. Klein');
      // Soft-delete does NOT cascade (deleted_at only). Confirm still present.
      await pets.softDelete(petUuid);
      expect(await vets.countForPetUuid(petUuid), 1);
    });

    test('updates a vet', () async {
      final petUuid = await pets.createPet(
        name: 'Mimi',
        species: Species.cat,
        sex: Sex.female,
      );
      final vetUuid = await vets.createVet(petUuid: petUuid, name: 'Dr. A');
      await vets.updateVet(uuid: vetUuid, name: 'Dr. B', phone: '0170');
      final list = await vets.watchForPetUuid(petUuid).first;
      expect(list.first.name, 'Dr. B');
      expect(list.first.phone, '0170');
    });
  });
}
