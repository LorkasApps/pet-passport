import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/households/data/household_stamper.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/sync/data/sync_outbox.dart';
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
      final result = await stamper.stampNullRows('h-123');
      expect(result.stamped, greaterThanOrEqualTo(2));
      expect(result.enqueued, 0,
          reason: 'no outbox supplied → no enqueue phase');

      final petRow = await db.petsDao.getByUuid(petUuid);
      expect(petRow?.householdId, 'h-123');

      final vetList = await vets.watchForPetUuid(petUuid).first;
      expect(vetList, hasLength(1));
      // watch() returns domain objects, so we probe the raw DAO row to
      // confirm the stamp landed in the underlying table.
      final vetsRawRows = await db.vetsDao.watchForPet(petRow!.id).first;
      expect(vetsRawRows.first.householdId, 'h-123');
    });

    test(
        'with an outbox: enqueues each stamped top-level row for its '
        'first push', () async {
      final db = newInMemoryDatabase();
      final pets = PetsRepository(db.petsDao);
      final vets = VetsRepository(db.vetsDao, db.petsDao);

      // Pre-cloud rows: no household_id, no enqueue at write time.
      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );
      await vets.createVet(petUuid: petUuid, name: 'Dr. Klein');

      // Sanity: nothing in the outbox yet.
      expect(await db.pendingOpsDao.count(), 0);

      final outbox = SyncOutbox(db);
      final result = await HouseholdStamper(db).stampNullRows(
        'h-primary',
        outbox: outbox,
      );

      // The pet + the vet both got stamped and enqueued. Other tables
      // are empty so they contribute nothing.
      expect(result.stamped, greaterThanOrEqualTo(2));
      expect(result.enqueued, 2);

      final ops = await db.pendingOpsDao.head();
      final tables = ops.map((o) => o.entityTable).toSet();
      expect(tables, containsAll(<String>{'pets', 'vets'}));

      // FK resolver still runs — vet's petId in the payload is the
      // parent's uuid string, not the local int.
      final vetOp = ops.firstWhere((o) => o.entityTable == 'vets');
      final payload = jsonDecode(vetOp.payloadJson) as Map<String, dynamic>;
      expect(payload['petId'], petUuid);
      expect(payload['petId'], isA<String>());
    });

    test('second call does not double-enqueue already-stamped rows',
        () async {
      final db = newInMemoryDatabase();
      final pets = PetsRepository(db.petsDao);
      await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
      );

      final outbox = SyncOutbox(db);
      final stamper = HouseholdStamper(db);
      final first = await stamper.stampNullRows('h-primary', outbox: outbox);
      final firstCount = await db.pendingOpsDao.count();

      final second =
          await stamper.stampNullRows('h-primary', outbox: outbox);
      final secondCount = await db.pendingOpsDao.count();

      expect(first.enqueued, 1);
      expect(second.enqueued, 0,
          reason: 'nothing was null-household this time');
      expect(secondCount, firstCount,
          reason: 'second call must not re-enqueue');
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
