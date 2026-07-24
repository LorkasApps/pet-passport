import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_passport/core/media/media_service.dart';
import 'package:pet_passport/features/insurances/data/insurances_repository.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';

import '../../helpers/database_helper.dart';

class MockMediaService extends Mock implements MediaService {}

void main() {
  group('InsurancesRepository', () {
    late PetsRepository pets;
    late InsurancesRepository insurances;
    late MockMediaService mediaService;

    setUp(() {
      final db = newInMemoryDatabase();
      pets = PetsRepository(db.petsDao, db);
      mediaService = MockMediaService();
      insurances = InsurancesRepository(
        db.insurancesDao,
        db.petsDao,
        mediaService,
      );
    });

    test('creates and lists insurances for a specific pet', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      final insUuid = await insurances.createInsurance(
        petUuid: petUuid,
        provider: 'Allianz',
        policyNumber: 'POL-12345',
        contractStart: DateTime(2026, 1, 1),
        contractEnd: DateTime(2027, 1, 1),
        notes: 'Premium coverage',
      );

      final list = await insurances.watchForPetUuid(petUuid).first;
      expect(list, hasLength(1));
      final insurance = list.first;
      expect(insurance.uuid, insUuid);
      expect(insurance.petUuid, petUuid);
      expect(insurance.provider, 'Allianz');
      expect(insurance.policyNumber, 'POL-12345');
      expect(insurance.contractStart, DateTime(2026, 1, 1));
      expect(insurance.contractEnd, DateTime(2027, 1, 1));
      expect(insurance.notes, 'Premium coverage');
      expect(insurance.documents, isEmpty);
    });

    test('counts insurances for a pet', () async {
      final petUuid = await pets.createPet(
        name: 'Mimi',
        species: Species.cat,
        sex: Sex.female,
      );
      expect(await insurances.countForPetUuid(petUuid), 0);

      await insurances.createInsurance(
        petUuid: petUuid,
        provider: 'AXA',
      );
      expect(await insurances.countForPetUuid(petUuid), 1);

      await insurances.createInsurance(
        petUuid: petUuid,
        provider: 'Generali',
      );
      expect(await insurances.countForPetUuid(petUuid), 2);
    });

    test('updates an insurance', () async {
      final petUuid = await pets.createPet(
        name: 'Fluffy',
        species: Species.dog,
        sex: Sex.female,
      );
      final insUuid = await insurances.createInsurance(
        petUuid: petUuid,
        provider: 'OldInsurance',
        policyNumber: 'OLD-123',
      );

      await insurances.updateInsurance(
        uuid: insUuid,
        provider: 'NewInsurance',
        policyNumber: 'NEW-456',
        notes: 'Updated coverage',
      );

      final list = await insurances.watchForPetUuid(petUuid).first;
      expect(list.first.provider, 'NewInsurance');
      expect(list.first.policyNumber, 'NEW-456');
      expect(list.first.notes, 'Updated coverage');
    });

    test('deletes an insurance and watches the removal', () async {
      final petUuid = await pets.createPet(
        name: 'Rex',
        species: Species.dog,
        sex: Sex.male,
      );
      final insUuid = await insurances.createInsurance(
        petUuid: petUuid,
        provider: 'DeleteMe',
      );

      final listBefore = await insurances.watchForPetUuid(petUuid).first;
      expect(listBefore, hasLength(1));

      await insurances.deleteByUuid(insUuid);

      final listAfter = await insurances.watchForPetUuid(petUuid).first;
      expect(listAfter, isEmpty);
    });

    test('soft-delete of a pet does NOT cascade-delete insurances', () async {
      final petUuid = await pets.createPet(
        name: 'SoftDeleteTest',
        species: Species.cat,
        sex: Sex.male,
      );
      await insurances.createInsurance(
        petUuid: petUuid,
        provider: 'SoftDelete1',
      );
      await insurances.createInsurance(
        petUuid: petUuid,
        provider: 'SoftDelete2',
      );

      expect(await insurances.countForPetUuid(petUuid), 2);

      // Soft-delete the pet
      await pets.softDelete(petUuid);

      // Insurances should still be present (soft-delete does NOT cascade)
      expect(await insurances.countForPetUuid(petUuid), 2);
    });

    test('watchByUuid returns single insurance with documents', () async {
      final petUuid = await pets.createPet(
        name: 'WatchTest',
        species: Species.dog,
        sex: Sex.male,
      );
      final insUuid = await insurances.createInsurance(
        petUuid: petUuid,
        provider: 'TestProvider',
        policyNumber: 'WATCH-789',
      );

      final insurance =
          await insurances.watchByUuid(insUuid, petUuid).first;
      expect(insurance, isNotNull);
      expect(insurance!.uuid, insUuid);
      expect(insurance.provider, 'TestProvider');
      expect(insurance.policyNumber, 'WATCH-789');
      expect(insurance.documents, isEmpty);
    });
  });
}
