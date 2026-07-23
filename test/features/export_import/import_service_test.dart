import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' show Value;
import 'package:pet_passport/core/db/database.dart';
import 'package:pet_passport/core/media/media_service.dart';
import 'package:pet_passport/features/appointments/data/appointments_repository.dart';
import 'package:pet_passport/features/appointments/domain/appointment_enums.dart';
import 'package:pet_passport/features/diet/data/foods_repository.dart';
import 'package:pet_passport/features/diet/domain/food_enums.dart';
import 'package:pet_passport/features/export_import/data/export_service.dart';
import 'package:pet_passport/features/export_import/data/import_service.dart';
import 'package:pet_passport/features/insurances/data/insurances_repository.dart';
import 'package:pet_passport/features/medications/data/medications_repository.dart';
import 'package:pet_passport/features/medications/domain/medication_enums.dart';
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
      final sourceAppointments = AppointmentsRepository(
        sourceDb.appointmentsDao,
        sourceDb.petsDao,
        sourceDb.vetsDao,
      );
      final sourceMedications = MedicationsRepository(
        sourceDb.medicationsDao,
        sourceDb.petsDao,
        sourceDb.vetsDao,
      );
      final sourceFoods =
          FoodsRepository(sourceDb.foodsDao, sourceDb.petsDao);
      final exportService = ExportService(
        sourcePets,
        sourceVets,
        sourceInsurances,
        sourceVacs,
        sourceEvents,
        sourceAppointments,
        sourceMedications,
        sourceFoods,
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
      final apptUuid = await sourceAppointments.createAppointment(
        petUuid: petUuid,
        type: AppointmentType.vet,
        title: 'Kontrolle',
        startsAt: DateTime(2026, 8, 1, 10, 30),
        durationMinutes: 45,
        vetUuid: vetUuid,
        location: 'Praxis',
        reminderOffsetsMinutes: const [60, 1440],
      );
      final medUuid = await sourceMedications.createMedication(
        petUuid: petUuid,
        name: 'Metacam',
        dosageAmount: 1.5,
        dosageUnit: 'mg',
        freqType: FreqType.daily,
        timesOfDay: const ['08:00', '20:00'],
        startsAt: DateTime(2026, 7, 1),
        prescribedByVetUuid: vetUuid,
        withFood: true,
      );
      final foodUuid = await sourceFoods.createFood(
        petUuid: petUuid,
        brand: 'Josera',
        name: 'Adult',
        foodType: FoodType.dry,
        portionGrams: 220,
        timesOfDay: const ['07:00', '19:00'],
        startsAt: DateTime(2026, 6, 1),
        remindersEnabled: true,
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
      expect(summary.appointmentsInserted, 1);
      expect(summary.medicationsInserted, 1);
      expect(summary.foodsInserted, 1);

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

      final targetAppointments = AppointmentsRepository(
        targetDb.appointmentsDao,
        targetDb.petsDao,
        targetDb.vetsDao,
      );
      final appts = await targetAppointments.watchForPetUuid(petUuid).first;
      expect(appts, hasLength(1));
      expect(appts.single.uuid, apptUuid);
      expect(appts.single.title, 'Kontrolle');
      expect(appts.single.vetUuid, vetUuid);
      expect(appts.single.reminderOffsetsMinutes, [60, 1440]);

      final targetMedications = MedicationsRepository(
        targetDb.medicationsDao,
        targetDb.petsDao,
        targetDb.vetsDao,
      );
      final meds = await targetMedications.watchForPetUuid(petUuid).first;
      expect(meds, hasLength(1));
      expect(meds.single.uuid, medUuid);
      expect(meds.single.name, 'Metacam');
      expect(meds.single.timesOfDay, ['08:00', '20:00']);
      expect(meds.single.prescribedByVetUuid, vetUuid);
      expect(meds.single.withFood, isTrue);

      final targetFoods =
          FoodsRepository(targetDb.foodsDao, targetDb.petsDao);
      final foods = await targetFoods.watchForPetUuid(petUuid).first;
      expect(foods, hasLength(1));
      expect(foods.single.uuid, foodUuid);
      expect(foods.single.brand, 'Josera');
      expect(foods.single.timesOfDay, ['07:00', '19:00']);
      expect(foods.single.remindersEnabled, isTrue);
    });

    test('food photos survive export → import round-trip', () async {
      // Photos rely on file paths from the source device. Round-trip only
      // needs to preserve the DB row metadata — the on-disk bytes are the
      // user's responsibility (see media sweep). We inject a photo row
      // directly to avoid depending on a real filesystem.
      final sourceDb = newInMemoryDatabase();
      final sourcePets = PetsRepository(sourceDb.petsDao);
      final sourceFoods =
          FoodsRepository(sourceDb.foodsDao, sourceDb.petsDao);

      final petUuid = await sourcePets.createPet(
        name: 'Balu',
        species: Species.dog,
        sex: Sex.male,
      );
      final foodUuid = await sourceFoods.createFood(
        petUuid: petUuid,
        brand: 'Josera',
        name: 'Adult',
        foodType: FoodType.dry,
        startsAt: DateTime(2026, 6, 1),
      );
      // Attach a photo row without touching the filesystem.
      final foodId = (await sourceDb.foodsDao.getByUuid(foodUuid))!.id;
      const photoUuid = 'photo-uuid-1';
      await sourceDb.foodsDao.insertPhoto(FoodPhotosCompanion.insert(
        uuid: photoUuid,
        foodId: foodId,
        filePath: 'foods/$foodUuid/$photoUuid.jpg',
        mimeType: 'image/jpeg',
        originalFilename: const Value('bag.jpg'),
        sizeBytes: const Value(12345),
        createdAt: DateTime(2026, 6, 2, 12),
      ));

      final exportService = ExportService(
        sourcePets,
        VetsRepository(sourceDb.vetsDao, sourceDb.petsDao),
        InsurancesRepository(
            sourceDb.insurancesDao, sourceDb.petsDao, MockMediaService()),
        VaccinationsRepository(
            sourceDb.vaccinationsDao, sourceDb.petsDao, sourceDb.vetsDao),
        EventsRepository(
            sourceDb, sourceDb.eventsDao, sourceDb.petsDao, MockMediaService()),
        AppointmentsRepository(
            sourceDb.appointmentsDao, sourceDb.petsDao, sourceDb.vetsDao),
        MedicationsRepository(
            sourceDb.medicationsDao, sourceDb.petsDao, sourceDb.vetsDao),
        sourceFoods,
      );
      final jsonString = jsonEncode(await exportService.buildSnapshot());

      final targetDb = newInMemoryDatabase();
      final summary =
          await ImportService(targetDb).importFromJsonString(jsonString);
      expect(summary.errors, isEmpty);
      expect(summary.foodsInserted, 1);

      final targetFoods = FoodsRepository(targetDb.foodsDao, targetDb.petsDao);
      final photos = await targetFoods.watchPhotos(foodUuid).first;
      expect(photos, hasLength(1));
      expect(photos.single.uuid, photoUuid);
      expect(photos.single.filePath, 'foods/$foodUuid/$photoUuid.jpg');
      expect(photos.single.originalFilename, 'bag.jpg');
      expect(photos.single.sizeBytes, 12345);
    });
  });
}
