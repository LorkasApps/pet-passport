import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_passport/core/media/media_service.dart';
import 'package:pet_passport/features/export_import/data/export_service.dart';
import 'package:pet_passport/features/export_import/data/import_service.dart';
import 'package:pet_passport/features/insurances/data/insurances_repository.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/protocol/data/events_repository.dart';
import 'package:pet_passport/features/vaccinations/data/vaccinations_repository.dart';
import 'package:pet_passport/features/vets/data/vets_repository.dart';

import '../../helpers/database_helper.dart';

class MockMediaService extends Mock implements MediaService {}

void main() {
  group('Export → Import round-trip', () {
    test('reimporting an exported snapshot restores pet + vet + vaccination',
        () async {
      // ---- Source DB: populate it, export a snapshot. ----
      final sourceDb = newInMemoryDatabase();
      final sourcePets = PetsRepository(sourceDb.petsDao);
      final sourceVets = VetsRepository(sourceDb.vetsDao, sourceDb.petsDao);
      final sourceVacs = VaccinationsRepository(
        sourceDb.vaccinationsDao,
        sourceDb.petsDao,
        sourceDb.vetsDao,
      );
      final sourceInsurances = InsurancesRepository(
        sourceDb.insurancesDao,
        sourceDb.petsDao,
        MockMediaService(),
      );
      final sourceEvents = EventsRepository(
        sourceDb,
        sourceDb.eventsDao,
        sourceDb.petsDao,
        MockMediaService(),
      );
      final exportService = ExportService(
        sourcePets,
        sourceVets,
        sourceInsurances,
        sourceVacs,
        sourceEvents,
      );

      final petUuid = await sourcePets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
        breed: 'Labrador',
      );
      final vetUuid = await sourceVets.createVet(
        petUuid: petUuid,
        name: 'Dr. Klein',
        phone: '+49 123 456',
      );
      final vacUuid = await sourceVacs.createVaccination(
        petUuid: petUuid,
        vaccineName: 'Tollwut',
        administeredAt: DateTime(2026, 3, 1),
        nextDueAt: DateTime(2027, 3, 1),
        vetUuid: vetUuid,
      );

      final snapshot = await exportService.buildSnapshot();
      final jsonString = jsonEncode(snapshot);

      // ---- Fresh target DB: import, verify contents. ----
      final targetDb = newInMemoryDatabase();
      final importer = ImportService(targetDb);
      final summary = await importer.importFromJsonString(jsonString);

      expect(summary.petsInserted, 1);
      expect(summary.vetsInserted, 1);
      expect(summary.vaccinationsInserted, 1);

      final targetPets = PetsRepository(targetDb.petsDao);
      final imported = await targetPets.getByUuid(petUuid);
      expect(imported, isNotNull);
      expect(imported!.name, 'Bello');
      expect(imported.breed, 'Labrador');

      final targetVets = VetsRepository(targetDb.vetsDao, targetDb.petsDao);
      final vets = await targetVets.watchForPetUuid(petUuid).first;
      expect(vets, hasLength(1));
      expect(vets.single.uuid, vetUuid);
      expect(vets.single.phone, '+49 123 456');

      final targetVacs = VaccinationsRepository(
        targetDb.vaccinationsDao,
        targetDb.petsDao,
        targetDb.vetsDao,
      );
      final vacs = await targetVacs.watchForPetUuid(petUuid).first;
      expect(vacs, hasLength(1));
      expect(vacs.single.uuid, vacUuid);
      expect(vacs.single.vetUuid, vetUuid);
    });
  });
}
