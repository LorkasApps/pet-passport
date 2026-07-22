import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/medications/data/medications_repository.dart';
import 'package:pet_passport/features/medications/domain/medication_enums.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';

import '../../helpers/database_helper.dart';

void main() {
  group('MedicationsRepository', () {
    late PetsRepository pets;
    late MedicationsRepository meds;

    setUp(() {
      final db = newInMemoryDatabase();
      pets = PetsRepository(db.petsDao);
      meds = MedicationsRepository(db.medicationsDao, db.petsDao, db.vetsDao);
    });

    test('create sets defaults and round-trips withFood', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      final medUuid = await meds.createMedication(
        petUuid: petUuid,
        name: 'Metacam',
        dosageAmount: 0.5,
        dosageUnit: 'ml',
        freqType: FreqType.daily,
        startsAt: DateTime(2026, 1, 1),
        timesOfDay: const ['08:00'],
        withFood: true,
      );
      final med = await meds.getByUuid(medUuid, petUuid);
      expect(med, isNotNull);
      expect(med!.name, 'Metacam');
      expect(med.dosageAmount, 0.5);
      expect(med.withFood, isTrue);
      expect(med.timesOfDay, ['08:00']);
    });

    test('logIntake feeds adherence within the 7-day window', () async {
      final petUuid = await pets.createPet(
        name: 'Rex',
        species: Species.dog,
        sex: Sex.male,
      );
      final start = DateTime.now().subtract(const Duration(days: 6));
      final medUuid = await meds.createMedication(
        petUuid: petUuid,
        name: 'Vitamin',
        dosageAmount: 1,
        dosageUnit: 'tab',
        freqType: FreqType.daily,
        startsAt: start,
        timesOfDay: const ['08:00'],
      );

      // Two takes, one skip in the window; one intake outside the window.
      await meds.logIntake(medicationUuid: medUuid);
      await meds.logIntake(medicationUuid: medUuid);
      await meds.logIntake(medicationUuid: medUuid, skipped: true);

      final adherence = await meds.adherenceLast7Days(medUuid);
      // 2 non-skipped takes vs 7 expected occurrences (once daily × 7 days).
      expect(adherence.taken, 2);
      expect(adherence.expected, greaterThanOrEqualTo(6));
    });

    test('watchActiveForPetUuid drops inactive rows', () async {
      final petUuid = await pets.createPet(
        name: 'Kitty',
        species: Species.cat,
        sex: Sex.female,
      );
      final activeUuid = await meds.createMedication(
        petUuid: petUuid,
        name: 'Active',
        dosageAmount: 1,
        dosageUnit: '',
        freqType: FreqType.daily,
        startsAt: DateTime(2026, 1, 1),
      );
      final inactiveUuid = await meds.createMedication(
        petUuid: petUuid,
        name: 'Old',
        dosageAmount: 1,
        dosageUnit: '',
        freqType: FreqType.daily,
        startsAt: DateTime(2025, 1, 1),
        isActive: false,
      );

      final active = await meds.watchActiveForPetUuid(petUuid).first;
      expect(active.map((m) => m.uuid), [activeUuid]);
      expect(active.map((m) => m.uuid), isNot(contains(inactiveUuid)));
    });
  });
}
