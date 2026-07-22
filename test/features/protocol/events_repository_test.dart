import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_passport/core/media/media_service.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/protocol/data/events_repository.dart';
import 'package:pet_passport/features/protocol/domain/event_enums.dart';
import 'package:pet_passport/features/protocol/domain/event_payload.dart';

import '../../helpers/database_helper.dart';

class MockMediaService extends Mock implements MediaService {}

void main() {
  setUpAll(() {
    registerFallbackValue(File(''));
  });

  group('EventsRepository', () {
    late PetsRepository pets;
    late EventsRepository events;
    late MockMediaService mediaService;

    setUp(() {
      final db = newInMemoryDatabase();
      pets = PetsRepository(db.petsDao);
      mediaService = MockMediaService();
      events = EventsRepository(db, db.eventsDao, db.petsDao, mediaService);
    });

    test('createEvent for a generic event returns uuid and appears in watchForPetUuid', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      final now = DateTime(2026, 7, 22, 10, 0);
      final eventUuid = await events.createEvent(
        petUuid: petUuid,
        type: EventType.generic,
        occurredAt: now,
        title: 'Generic Event',
        note: 'A note',
        payload: const GenericPayload(),
      );

      expect(eventUuid, isNotEmpty);

      final list = await events.watchForPetUuid(petUuid).first;
      expect(list, hasLength(1));
      final event = list.first;
      expect(event.uuid, eventUuid);
      expect(event.petUuid, petUuid);
      expect(event.type, EventType.generic);
      expect(event.title, 'Generic Event');
      expect(event.note, 'A note');
    });

    test('createEvent for weight writes both event and pet_weights row', () async {
      final db = newInMemoryDatabase();
      pets = PetsRepository(db.petsDao);
      events = EventsRepository(db, db.eventsDao, db.petsDao, mediaService);

      final petUuid = await pets.createPet(
        name: 'Bella',
        species: Species.dog,
        sex: Sex.female,
      );
      final now = DateTime(2026, 7, 22, 10, 0);
      final eventUuid = await events.createEvent(
        petUuid: petUuid,
        type: EventType.weight,
        occurredAt: now,
        title: 'Weight Check',
        payload: const WeightPayload(weightKg: 12.4),
      );

      expect(eventUuid, isNotEmpty);

      // Check event appears in stream
      final eventList = await events.watchForPetUuid(petUuid).first;
      expect(eventList, hasLength(1));
      final event = eventList.first;
      expect(event.type, EventType.weight);
      expect(event.payload, isA<WeightPayload>());
      expect((event.payload as WeightPayload).weightKg, 12.4);

      // Check pet_weights row was created and linked
      final weights = await (db.select(db.petWeights)
            ..where((w) => w.sourceEventUuid.equals(eventUuid)))
          .get();
      expect(weights, hasLength(1));
      final weight = weights.first;
      expect(weight.weightKg, 12.4);
      expect(weight.sourceEventUuid, eventUuid);
    });

    test('updateEvent on a weight event updates pet_weights row (not duplicate)', () async {
      final db = newInMemoryDatabase();
      pets = PetsRepository(db.petsDao);
      events = EventsRepository(db, db.eventsDao, db.petsDao, mediaService);

      final petUuid = await pets.createPet(
        name: 'Bella',
        species: Species.dog,
        sex: Sex.female,
      );
      final now = DateTime(2026, 7, 22, 10, 0);
      final eventUuid = await events.createEvent(
        petUuid: petUuid,
        type: EventType.weight,
        occurredAt: now,
        payload: const WeightPayload(weightKg: 12.4),
      );

      // Verify initial weight
      var weights = await (db.select(db.petWeights)
            ..where((w) => w.sourceEventUuid.equals(eventUuid)))
          .get();
      expect(weights, hasLength(1));
      expect(weights.first.weightKg, 12.4);

      // Update event with new weight
      await events.updateEvent(
        uuid: eventUuid,
        type: EventType.weight,
        occurredAt: now,
        payload: const WeightPayload(weightKg: 12.6),
      );

      // Verify pet_weights row is updated, not duplicated
      weights = await (db.select(db.petWeights)
            ..where((w) => w.sourceEventUuid.equals(eventUuid)))
          .get();
      expect(weights, hasLength(1));
      expect(weights.first.weightKg, 12.6);
    });

    test('updateEvent changing type FROM weight TO generic deletes pet_weights row', () async {
      final db = newInMemoryDatabase();
      pets = PetsRepository(db.petsDao);
      events = EventsRepository(db, db.eventsDao, db.petsDao, mediaService);

      final petUuid = await pets.createPet(
        name: 'Bella',
        species: Species.dog,
        sex: Sex.female,
      );
      final now = DateTime(2026, 7, 22, 10, 0);
      final eventUuid = await events.createEvent(
        petUuid: petUuid,
        type: EventType.weight,
        occurredAt: now,
        payload: const WeightPayload(weightKg: 12.4),
      );

      // Verify pet_weights row exists
      var weights = await (db.select(db.petWeights)
            ..where((w) => w.sourceEventUuid.equals(eventUuid)))
          .get();
      expect(weights, hasLength(1));

      // Update event to generic type
      await events.updateEvent(
        uuid: eventUuid,
        type: EventType.generic,
        occurredAt: now,
        payload: const GenericPayload(),
      );

      // Verify pet_weights row is deleted
      weights = await (db.select(db.petWeights)
            ..where((w) => w.sourceEventUuid.equals(eventUuid)))
          .get();
      expect(weights, isEmpty);
    });

    test('deleteByUuid on a weight event deletes both event and pet_weights row', () async {
      final db = newInMemoryDatabase();
      pets = PetsRepository(db.petsDao);
      events = EventsRepository(db, db.eventsDao, db.petsDao, mediaService);

      final petUuid = await pets.createPet(
        name: 'Bella',
        species: Species.dog,
        sex: Sex.female,
      );
      final now = DateTime(2026, 7, 22, 10, 0);
      final eventUuid = await events.createEvent(
        petUuid: petUuid,
        type: EventType.weight,
        occurredAt: now,
        payload: const WeightPayload(weightKg: 12.4),
      );

      // Verify both event and weight exist
      var eventList = await events.watchForPetUuid(petUuid).first;
      expect(eventList, hasLength(1));
      var weights = await (db.select(db.petWeights)
            ..where((w) => w.sourceEventUuid.equals(eventUuid)))
          .get();
      expect(weights, hasLength(1));

      // Delete event
      await events.deleteByUuid(eventUuid);

      // Verify both are gone
      eventList = await events.watchForPetUuid(petUuid).first;
      expect(eventList, isEmpty);
      weights = await (db.select(db.petWeights)
            ..where((w) => w.sourceEventUuid.equals(eventUuid)))
          .get();
      expect(weights, isEmpty);
    });

    test('watchForPetUuid with typeFilter returns only symptom events', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      final now = DateTime(2026, 7, 22, 10, 0);

      // Create different event types
      await events.createEvent(
        petUuid: petUuid,
        type: EventType.symptom,
        occurredAt: now,
        payload: const SymptomPayload(
          description: 'Cough',
          severity: SymptomSeverity.medium,
        ),
      );
      await events.createEvent(
        petUuid: petUuid,
        type: EventType.generic,
        occurredAt: now.add(const Duration(hours: 1)),
        payload: const GenericPayload(),
      );
      await events.createEvent(
        petUuid: petUuid,
        type: EventType.symptom,
        occurredAt: now.add(const Duration(hours: 2)),
        payload: const SymptomPayload(
          description: 'Fever',
          severity: SymptomSeverity.high,
        ),
      );

      // Filter by symptom type
      final symptoms = await events.watchForPetUuid(
        petUuid,
        typeFilter: EventType.symptom,
      ).first;

      expect(symptoms, hasLength(2));
      expect(symptoms.every((e) => e.type == EventType.symptom), isTrue);
    });

    test('createTag returns uuid; calling again with same label returns SAME uuid (dedup)', () async {
      final tagUuid1 = await events.createTag(label: 'Important');
      final tagUuid2 = await events.createTag(label: 'Important');
      expect(tagUuid1, tagUuid2);
    });

    test('assignTag and unassignTag manage event tags correctly', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      final now = DateTime(2026, 7, 22, 10, 0);
      final eventUuid = await events.createEvent(
        petUuid: petUuid,
        type: EventType.generic,
        occurredAt: now,
        payload: const GenericPayload(),
      );

      // Create a tag
      final tagUuid = await events.createTag(label: 'Urgent');

      // Initially no tags
      var event = await events.getByUuid(eventUuid, petUuid);
      expect(event?.tags, isEmpty);

      // Assign tag
      await events.assignTag(eventUuid: eventUuid, tagUuid: tagUuid);

      // Verify tag is assigned
      event = await events.getByUuid(eventUuid, petUuid);
      expect(event?.tags, hasLength(1));
      expect(event?.tags.first.uuid, tagUuid);
      expect(event?.tags.first.label, 'Urgent');

      // Unassign tag
      await events.unassignTag(eventUuid: eventUuid, tagUuid: tagUuid);

      // Verify tag is removed
      event = await events.getByUuid(eventUuid, petUuid);
      expect(event?.tags, isEmpty);
    });

    test('attachPhoto saves file and removePhoto deletes it', () async {
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      final now = DateTime(2026, 7, 22, 10, 0);
      final eventUuid = await events.createEvent(
        petUuid: petUuid,
        type: EventType.generic,
        occurredAt: now,
        payload: const GenericPayload(),
      );

      // Setup mock media service
      when(
        () => mediaService.saveEventPhoto(
          eventUuid: eventUuid,
          photoUuid: any(named: 'photoUuid'),
          source: any(named: 'source'),
        ),
      ).thenAnswer((_) async => 'events/path/to/photo.jpg');

      when(() => mediaService.deleteFile(any())).thenAnswer((_) async {});

      // Attach photo
      final sourceFile = File('/tmp/test.jpg');
      final photoUuid = await events.attachPhoto(
        eventUuid: eventUuid,
        source: sourceFile,
        mimeType: 'image/jpeg',
        sizeBytes: 1024,
      );

      expect(photoUuid, isNotEmpty);

      // Verify photo appears in event
      var event = await events.getByUuid(eventUuid, petUuid);
      expect(event?.photos, hasLength(1));
      expect(event?.photos.first.uuid, photoUuid);
      expect(event?.photos.first.mimeType, 'image/jpeg');
      expect(event?.photos.first.sizeBytes, 1024);

      // Remove photo
      await events.removePhoto(photoUuid);

      // Verify photo is gone
      event = await events.getByUuid(eventUuid, petUuid);
      expect(event?.photos, isEmpty);

      // Verify deleteFile was called
      verify(() => mediaService.deleteFile(any())).called(1);
    });
  });
}
