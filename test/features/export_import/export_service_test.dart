import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_passport/core/media/media_service.dart';
import 'package:pet_passport/features/appointments/data/appointments_repository.dart';
import 'package:pet_passport/features/contacts/data/contacts_repository.dart';
import 'package:pet_passport/features/diet/data/foods_repository.dart';
import 'package:pet_passport/features/documents/data/documents_repository.dart';
import 'package:pet_passport/features/export_import/data/export_service.dart';
import 'package:pet_passport/features/insurances/data/insurances_repository.dart';
import 'package:pet_passport/features/medications/data/medications_repository.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/protocol/data/events_repository.dart';
import 'package:pet_passport/features/vaccinations/data/vaccinations_repository.dart';
import 'package:pet_passport/features/vets/data/vets_repository.dart';

import '../../helpers/database_helper.dart';

class MockMediaService extends Mock implements MediaService {}

void main() {
  group('ExportService', () {
    late PetsRepository pets;
    late VetsRepository vets;
    late InsurancesRepository insurances;
    late VaccinationsRepository vaccinations;
    late ExportService exportService;

    setUp(() {
      final db = newInMemoryDatabase();
      final mediaService = MockMediaService();
      pets = PetsRepository(db.petsDao);
      vets = VetsRepository(db.vetsDao, db.petsDao);
      insurances = InsurancesRepository(db.insurancesDao, db.petsDao, mediaService);
      vaccinations = VaccinationsRepository(
        db.vaccinationsDao,
        db.petsDao,
        db.vetsDao,
      );
      final events = EventsRepository(
        db,
        db.eventsDao,
        db.petsDao,
        mediaService,
      );
      final appointments = AppointmentsRepository(db.appointmentsDao, db.petsDao, db.vetsDao, db.contactsDao,
      );
      final medications = MedicationsRepository(
        db.medicationsDao,
        db.petsDao,
        db.vetsDao,
      );
      final foods = FoodsRepository(db.foodsDao, db.petsDao);
      final contacts = ContactsRepository(db.contactsDao, db.petsDao);
      final documents =
          DocumentsRepository(db.petDocumentsDao, db.petsDao, mediaService);
      exportService = ExportService(
        pets,
        vets,
        insurances,
        vaccinations,
        events,
        appointments,
        medications,
        foods,
        contacts,
        documents,
      );
    });

    test('buildSnapshot with empty database produces valid JSON structure', () async {
      final snapshot = await exportService.buildSnapshot();

      expect(snapshot, isA<Map<String, dynamic>>());
      expect(snapshot.keys, containsAll([
        'schema_version',
        'exported_at',
        'app_version',
        'pets',
      ]));

      expect(snapshot['schema_version'], equals(3));
      expect(snapshot['app_version'], equals('0.1.0+1'));
      expect(snapshot['pets'], isA<List<dynamic>>());
      expect(snapshot['pets'], isEmpty);
      expect(snapshot['exported_at'], isA<String>());

      // Verify exported_at is a valid ISO8601 datetime
      final exportedAt = DateTime.parse(snapshot['exported_at'] as String);
      expect(exportedAt, isA<DateTime>());
    });

    test(
      'buildSnapshot with 1 pet, 1 vet, 1 insurance, 1 vaccination contains all entities',
      () async {
        final now = DateTime(2026, 7, 22);
        final dueDate = DateTime(2027, 7, 22);

        // Create pet
        final petUuid = await pets.createPet(
          name: 'Bello',
          species: Species.dog,
          sex: Sex.male,
          isNeutered: true,
          breed: 'Labrador',
          dateOfBirth: DateTime(2020, 1, 15),
          color: 'Black',
          markings: 'White paws',
          chipNumber: 'CHIP123456789',
          tassoNumber: 'TASSO987654',
          tassoRegisteredAt: DateTime(2020, 2, 1),
          allergies: 'Chicken',
          notes: 'Very friendly',
        );

        // Create vet
        final vetUuid = await vets.createVet(
          petUuid: petUuid,
          name: 'Dr. Klein',
          practice: 'Happy Paws Clinic',
          address: '123 Pet Street',
          phone: '+49 123 456789',
          email: 'dr.klein@happypaws.de',
          notes: 'Excellent vet',
        );

        // Create insurance
        final insuranceUuid = await insurances.createInsurance(
          petUuid: petUuid,
          provider: 'Allianz',
          policyNumber: 'POL-2026-123456',
          contractStart: DateTime(2024, 1, 1),
          contractEnd: DateTime(2026, 12, 31),
          notes: 'Full coverage',
        );

        // Create vaccination
        final vaccinationUuid = await vaccinations.createVaccination(
          petUuid: petUuid,
          vaccineName: 'Tollwut',
          administeredAt: now,
          nextDueAt: dueDate,
          vetUuid: vetUuid,
          batchNumber: 'BATCH-2026-001',
          notes: 'Booster shot',
        );

        final snapshot = await exportService.buildSnapshot();

        // Verify structure
        expect(snapshot['pets'], hasLength(1));

        final petJson = snapshot['pets'][0] as Map<String, dynamic>;

        // Verify pet data
        expect(petJson['uuid'], equals(petUuid));
        expect(petJson['name'], equals('Bello'));
        expect(petJson['species'], equals('dog'));
        expect(petJson['sex'], equals('male'));
        expect(petJson['is_neutered'], equals(true));
        expect(petJson['breed'], equals('Labrador'));
        expect(petJson['color'], equals('Black'));
        expect(petJson['markings'], equals('White paws'));
        expect(petJson['chip_number'], equals('CHIP123456789'));
        expect(petJson['tasso_number'], equals('TASSO987654'));
        expect(petJson['allergies'], equals('Chicken'));
        expect(petJson['notes'], equals('Very friendly'));

        // Verify vet data
        expect(petJson['vets'], hasLength(1));
        final vetJson = petJson['vets'][0] as Map<String, dynamic>;
        expect(vetJson['uuid'], equals(vetUuid));
        expect(vetJson['name'], equals('Dr. Klein'));
        expect(vetJson['practice'], equals('Happy Paws Clinic'));
        expect(vetJson['address'], equals('123 Pet Street'));
        expect(vetJson['phone'], equals('+49 123 456789'));
        expect(vetJson['email'], equals('dr.klein@happypaws.de'));
        expect(vetJson['notes'], equals('Excellent vet'));

        // Verify insurance data
        expect(petJson['insurances'], hasLength(1));
        final insuranceJson = petJson['insurances'][0] as Map<String, dynamic>;
        expect(insuranceJson['uuid'], equals(insuranceUuid));
        expect(insuranceJson['provider'], equals('Allianz'));
        expect(insuranceJson['policy_number'], equals('POL-2026-123456'));
        expect(insuranceJson['documents'], isA<List<dynamic>>());
        expect(insuranceJson['documents'], isEmpty);

        // Verify vaccination data
        expect(petJson['vaccinations'], hasLength(1));
        final vaccinationJson = petJson['vaccinations'][0] as Map<String, dynamic>;
        expect(vaccinationJson['uuid'], equals(vaccinationUuid));
        expect(vaccinationJson['vaccine_name'], equals('Tollwut'));
        expect(vaccinationJson['vet_uuid'], equals(vetUuid));
        expect(vaccinationJson['batch_number'], equals('BATCH-2026-001'));
        expect(vaccinationJson['notes'], equals('Booster shot'));
        expect(vaccinationJson['documents'], isA<List<dynamic>>());
        expect(vaccinationJson['documents'], isEmpty);
      },
    );

    test('buildSnapshot JSON is parseable with jsonDecode', () async {
      final petUuid = await pets.createPet(
        name: 'Fluffy',
        species: Species.cat,
        sex: Sex.female,
      );

      await vets.createVet(
        petUuid: petUuid,
        name: 'Dr. Cat Specialist',
      );

      final snapshot = await exportService.buildSnapshot();

      // Convert to JSON string and back
      final jsonString = jsonEncode(snapshot);
      expect(jsonString, isA<String>());

      // Verify it can be parsed back
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['schema_version'], equals(3));
      expect(decoded['pets'], isA<List<dynamic>>());
      expect(decoded['pets'][0]['name'], equals('Fluffy'));
    });

    test('buildSnapshot has expected top-level keys', () async {
      final snapshot = await exportService.buildSnapshot();

      final expectedKeys = {'schema_version', 'exported_at', 'app_version', 'tags', 'pets'};
      expect(snapshot.keys.toSet(), equals(expectedKeys));
    });

    test('buildSnapshot with multiple pets includes all entities for each pet', () async {
      // Create first pet with vet
      final pet1Uuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      final vet1Uuid = await vets.createVet(
        petUuid: pet1Uuid,
        name: 'Dr. Klein',
      );

      // Create second pet with different vet
      final pet2Uuid = await pets.createPet(
        name: 'Mittens',
        species: Species.cat,
        sex: Sex.female,
      );
      final vet2Uuid = await vets.createVet(
        petUuid: pet2Uuid,
        name: 'Dr. Feline',
      );

      final snapshot = await exportService.buildSnapshot();

      expect(snapshot['pets'], hasLength(2));

      final pet1Json = snapshot['pets'][0] as Map<String, dynamic>;
      final pet2Json = snapshot['pets'][1] as Map<String, dynamic>;

      expect(pet1Json['uuid'], equals(pet1Uuid));
      expect(pet1Json['name'], equals('Bello'));
      expect(pet1Json['vets'], hasLength(1));
      expect((pet1Json['vets'][0] as Map<String, dynamic>)['uuid'], equals(vet1Uuid));

      expect(pet2Json['uuid'], equals(pet2Uuid));
      expect(pet2Json['name'], equals('Mittens'));
      expect(pet2Json['vets'], hasLength(1));
      expect((pet2Json['vets'][0] as Map<String, dynamic>)['uuid'], equals(vet2Uuid));
    });

  });
}
