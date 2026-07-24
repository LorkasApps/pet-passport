import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/vaccinations/data/vaccinations_repository.dart';
import 'package:pet_passport/features/vets/data/vets_repository.dart';

import '../../helpers/database_helper.dart';

void main() {
  group('VaccinationsRepository', () {
    late PetsRepository pets;
    late VetsRepository vets;
    late VaccinationsRepository vacs;

    setUp(() {
      final db = newInMemoryDatabase();
      pets = PetsRepository(db.petsDao, db);
      vets = VetsRepository(db.vetsDao, db.petsDao);
      vacs = VaccinationsRepository(db.vaccinationsDao, db.petsDao, db.vetsDao);
    });

    test('creates and lists a vaccination for a pet', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      final vetUuid = await vets.createVet(
        petUuid: petUuid,
        name: 'Dr. Klein',
      );
      final now = DateTime(2026, 7, 22);
      final due = DateTime(2027, 7, 22);
      final vacUuid = await vacs.createVaccination(
        petUuid: petUuid,
        vaccineName: 'Tollwut',
        administeredAt: now,
        nextDueAt: due,
        vetUuid: vetUuid,
        batchNumber: 'A-42',
      );

      final list = await vacs.watchForPetUuid(petUuid).first;
      expect(list, hasLength(1));
      final v = list.first;
      expect(v.uuid, vacUuid);
      expect(v.vaccineName, 'Tollwut');
      expect(v.administeredAt, now);
      expect(v.nextDueAt, due);
      expect(v.vetUuid, vetUuid);
      expect(v.batchNumber, 'A-42');
    });

    test('vet reference resets to null when vet is deleted', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      final vetUuid = await vets.createVet(
        petUuid: petUuid,
        name: 'Dr. Klein',
      );
      await vacs.createVaccination(
        petUuid: petUuid,
        vaccineName: 'Tollwut',
        administeredAt: DateTime(2026, 1, 1),
        vetUuid: vetUuid,
      );
      await vets.deleteByUuid(vetUuid);
      final list = await vacs.watchForPetUuid(petUuid).first;
      expect(list.single.vetUuid, isNull);
    });

    test('marks a vaccination overdue when next_due is in the past', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      await vacs.createVaccination(
        petUuid: petUuid,
        vaccineName: 'Tollwut',
        administeredAt: DateTime(2024, 1, 1),
        nextDueAt: DateTime(2025, 1, 1),
      );
      final list = await vacs.watchForPetUuid(petUuid).first;
      expect(list.single.isOverdue, isTrue);
    });
  });
}
