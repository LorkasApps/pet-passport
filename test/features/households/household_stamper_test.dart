import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/households/data/household_stamper.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/vets/data/vets_repository.dart';

import '../../helpers/database_helper.dart';

void main() {
  group('HouseholdStamper', () {
    test('stamps null household_id on every top-level table', () async {
      final db = newInMemoryDatabase();
      final pets = PetsRepository(db.petsDao);
      final vets = VetsRepository(db.vetsDao, db.petsDao);

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

      final stamper = HouseholdStamper(db);
      final touched = await stamper.stampNullRows('h-123');
      expect(touched, greaterThanOrEqualTo(2));

      final petRow = await db.petsDao.getByUuid(petUuid);
      expect(petRow?.householdId, 'h-123');

      final vetList = await vets.watchForPetUuid(petUuid).first;
      expect(vetList, hasLength(1));
      // watch() returns domain objects, so we probe the raw DAO row to
      // confirm the stamp landed in the underlying table.
      final vetsRawRows = await db.vetsDao.watchForPet(petRow!.id).first;
      expect(vetsRawRows.first.householdId, 'h-123');
    });

    test('leaves rows with an existing household_id untouched', () async {
      final db = newInMemoryDatabase();
      final pets = PetsRepository(db.petsDao);

      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      final stamper = HouseholdStamper(db);
      await stamper.stampNullRows('h-first');
      // Second call for a different household must not overwrite the
      // already-stamped id — this is the re-install / multi-device
      // safety property we care about.
      await stamper.stampNullRows('h-second');
      final row = await db.petsDao.getByUuid(petUuid);
      expect(row?.householdId, 'h-first');
    });
  });
}
