import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' show Value;
import 'package:pet_passport/core/db/database.dart';
import 'package:pet_passport/core/media/media_service.dart';
import 'package:pet_passport/features/appointments/data/appointments_repository.dart';
import 'package:pet_passport/features/appointments/domain/appointment_enums.dart';
import 'package:pet_passport/features/contacts/data/contacts_repository.dart';
import 'package:pet_passport/features/contacts/domain/contact_enums.dart';
import 'package:pet_passport/features/diet/data/foods_repository.dart';
import 'package:pet_passport/features/documents/data/documents_repository.dart';
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
      final sourcePets = PetsRepository(sourceDb.petsDao, sourceDb);
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
      final sourceAppointments = AppointmentsRepository(sourceDb.appointmentsDao, sourceDb.petsDao, sourceDb.vetsDao, sourceDb.contactsDao,
      );
      final sourceMedications = MedicationsRepository(
        sourceDb.medicationsDao,
        sourceDb.petsDao,
        sourceDb.vetsDao,
      );
      final sourceFoods =
          FoodsRepository(sourceDb.foodsDao, sourceDb.petsDao);
      final sourceContacts =
          ContactsRepository(sourceDb.contactsDao, sourceDb.petsDao);
      final sourceDocuments = DocumentsRepository(
          sourceDb.petDocumentsDao, sourceDb.petsDao, MockMediaService());
      final exportService = ExportService(
        sourcePets,
        sourceVets,
        sourceInsurances,
        sourceVacs,
        sourceEvents,
        sourceAppointments,
        sourceMedications,
        sourceFoods,
        sourceContacts,
        sourceDocuments,
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
      final contactUuid = await sourceContacts.createContact(
        petUuid: petUuid,
        name: 'Jan Sitter',
        role: ContactRole.sitter,
        phone: '+49 555 12345',
      );
      final trainAppointmentUuid =
          await sourceAppointments.createAppointment(
        petUuid: petUuid,
        type: AppointmentType.training,
        title: 'Hundeschule',
        startsAt: DateTime(2026, 8, 3, 17),
        contactUuid: contactUuid,
        location: 'Trainingsplatz',
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
      // Documents are stored purely by file path — the media bytes stay
      // on the source device, so we inject a row directly.
      final petRow = (await sourceDb.petsDao.getByUuid(petUuid))!;
      const docUuid = 'doc-uuid-1';
      await sourceDb.petDocumentsDao.insertDoc(PetDocumentsCompanion.insert(
        uuid: docUuid,
        petId: petRow.id,
        title: const Value('Blutbild Mai'),
        filePath: 'pets/$petUuid/docs/$docUuid.pdf',
        mimeType: 'application/pdf',
        originalFilename: const Value('blutbild.pdf'),
        sizeBytes: const Value(45678),
        notes: const Value('Referenzwerte im Notizfeld.'),
        createdAt: DateTime(2026, 5, 20),
        updatedAt: DateTime(2026, 5, 20),
      ));

      final snapshot = await exportService.buildSnapshot();
      final jsonString = jsonEncode(snapshot);

      // ---- Fresh target DB: import, verify contents. ----
      final targetDb = newInMemoryDatabase();
      final importer = ImportService(targetDb);
      final summary = await importer.importFromJsonString(jsonString);

      expect(summary.petsInserted, 1);
      expect(summary.vetsInserted, 1);
      expect(summary.vaccinationsInserted, 1);
      expect(summary.appointmentsInserted, 2);
      expect(summary.contactsInserted, 1);
      expect(summary.medicationsInserted, 1);
      expect(summary.foodsInserted, 1);
      expect(summary.documentsInserted, 1);

      final targetPets = PetsRepository(targetDb.petsDao, targetDb);
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

      final targetAppointments = AppointmentsRepository(targetDb.appointmentsDao, targetDb.petsDao, targetDb.vetsDao, targetDb.contactsDao,
      );
      final appts = await targetAppointments.watchForPetUuid(petUuid).first;
      expect(appts, hasLength(2));
      final vetAppt = appts.firstWhere((a) => a.uuid == apptUuid);
      expect(vetAppt.title, 'Kontrolle');
      expect(vetAppt.vetUuid, vetUuid);
      expect(vetAppt.contactUuid, isNull);
      expect(vetAppt.reminderOffsetsMinutes, [60, 1440]);
      final trainAppt =
          appts.firstWhere((a) => a.uuid == trainAppointmentUuid);
      expect(trainAppt.vetUuid, isNull);
      expect(trainAppt.contactUuid, contactUuid);
      expect(trainAppt.location, 'Trainingsplatz');

      final targetContacts =
          ContactsRepository(targetDb.contactsDao, targetDb.petsDao);
      final contacts = await targetContacts.watchForPetUuid(petUuid).first;
      expect(contacts, hasLength(1));
      expect(contacts.single.uuid, contactUuid);
      expect(contacts.single.role, ContactRole.sitter);
      expect(contacts.single.phone, '+49 555 12345');

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

      final targetDocuments = DocumentsRepository(
          targetDb.petDocumentsDao, targetDb.petsDao, MockMediaService());
      final docs = await targetDocuments.watchForPetUuid(petUuid).first;
      expect(docs, hasLength(1));
      expect(docs.single.uuid, docUuid);
      expect(docs.single.title, 'Blutbild Mai');
      expect(docs.single.mimeType, 'application/pdf');
      expect(docs.single.originalFilename, 'blutbild.pdf');
      expect(docs.single.sizeBytes, 45678);
    });

    test('food photos survive export → import round-trip', () async {
      // Photos rely on file paths from the source device. Round-trip only
      // needs to preserve the DB row metadata — the on-disk bytes are the
      // user's responsibility (see media sweep). We inject a photo row
      // directly to avoid depending on a real filesystem.
      final sourceDb = newInMemoryDatabase();
      final sourcePets = PetsRepository(sourceDb.petsDao, sourceDb);
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
        title: const Value('Vorderseite'),
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
        AppointmentsRepository(sourceDb.appointmentsDao, sourceDb.petsDao,
            sourceDb.vetsDao, sourceDb.contactsDao),
        MedicationsRepository(
            sourceDb.medicationsDao, sourceDb.petsDao, sourceDb.vetsDao),
        sourceFoods,
        ContactsRepository(sourceDb.contactsDao, sourceDb.petsDao),
        DocumentsRepository(
            sourceDb.petDocumentsDao, sourceDb.petsDao, MockMediaService()),
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
      expect(photos.single.title, 'Vorderseite');
      expect(photos.single.filePath, 'foods/$foodUuid/$photoUuid.jpg');
      expect(photos.single.originalFilename, 'bag.jpg');
      expect(photos.single.sizeBytes, 12345);
    });
  });
}
