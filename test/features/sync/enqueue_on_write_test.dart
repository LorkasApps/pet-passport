import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/sync/data/sync_outbox.dart';
import 'package:pet_passport/features/vets/data/vets_repository.dart';

import '../../helpers/database_helper.dart';

/// Guardrails for M3-02 wiring: every write on a top-level entity with a
/// non-null household_id must land in the outbox, and every write on a
/// local-only row (household_id == null) must NOT.
///
/// We use PetsRepository as the parent (only one method takes household_id
/// directly) and VetsRepository as a stand-in for the pet-scoped child
/// repos (contacts/appointments/… all share the same enqueue helper
/// pattern; a full parametric matrix would be busywork).
void main() {
  group('SyncOutbox enqueue-on-write — parent (pets)', () {
    test('createPet with householdId enqueues one upsert', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);
      final repo = PetsRepository(db.petsDao, outbox: outbox);

      final uuid = await repo.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );

      final ops = await db.pendingOpsDao.head();
      expect(ops, hasLength(1));
      final op = ops.single;
      expect(op.opType, 'upsert');
      expect(op.entityTable, 'pets');
      expect(op.entityUuid, uuid);
      expect(op.householdId, 'h-1');
      final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
      expect(payload['uuid'], uuid);
      expect(payload['name'], 'Bello');
      expect(payload['householdId'], 'h-1');
    });

    test('createPet WITHOUT householdId does not enqueue', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);
      final repo = PetsRepository(db.petsDao, outbox: outbox);

      await repo.createPet(
        name: 'Solo',
        species: Species.dog,
        sex: Sex.male,
      );

      expect(await outbox.pendingCount(), 0);
    });

    test('updatePet on cloud pet enqueues a fresh upsert', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);
      final repo = PetsRepository(db.petsDao, outbox: outbox);

      final uuid = await repo.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );
      // A second write must produce a second op — dedup happens in the
      // drain, not at enqueue time.
      await repo.updatePet(
        uuid: uuid,
        name: 'Bello II',
        species: Species.dog,
        sex: Sex.male,
      );

      final ops = await db.pendingOpsDao.head();
      expect(ops, hasLength(2));
      final latest = ops.last;
      final payload = jsonDecode(latest.payloadJson) as Map<String, dynamic>;
      expect(payload['name'], 'Bello II');
    });

    test('softDelete on cloud pet enqueues an upsert with tombstone',
        () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);
      final repo = PetsRepository(db.petsDao, outbox: outbox);

      final uuid = await repo.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );
      await repo.softDelete(uuid);

      final ops = await db.pendingOpsDao.head();
      expect(ops, hasLength(2));
      final latest = ops.last;
      expect(latest.opType, 'upsert');
      final payload = jsonDecode(latest.payloadJson) as Map<String, dynamic>;
      expect(payload['deletedAt'], isNotNull);
    });

    test('updatePet on local-only pet does not enqueue', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);
      final repo = PetsRepository(db.petsDao, outbox: outbox);

      final uuid = await repo.createPet(
        name: 'Solo',
        species: Species.dog,
        sex: Sex.male,
      );
      await repo.updatePet(
        uuid: uuid,
        name: 'Solo II',
        species: Species.dog,
        sex: Sex.male,
      );

      expect(await outbox.pendingCount(), 0);
    });
  });

  group('SyncOutbox enqueue-on-write — child (vets inherits from pet)', () {
    test('createVet inherits householdId from the pet and enqueues',
        () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final vets = VetsRepository(db.vetsDao, db.petsDao, outbox: outbox);

      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );
      final vetUuid = await vets.createVet(
        petUuid: petUuid,
        name: 'Dr. Klein',
      );

      final ops = await db.pendingOpsDao.head();
      // one pets op + one vets op
      expect(ops, hasLength(2));
      final vetOp = ops.firstWhere((o) => o.entityTable == 'vets');
      expect(vetOp.entityUuid, vetUuid);
      expect(vetOp.householdId, 'h-1');
      final payload = jsonDecode(vetOp.payloadJson) as Map<String, dynamic>;
      expect(payload['householdId'], 'h-1');
    });

    test('softDelete of a child row enqueues a tombstone upsert',
        () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final vets = VetsRepository(db.vetsDao, db.petsDao, outbox: outbox);

      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );
      final vetUuid = await vets.createVet(
        petUuid: petUuid,
        name: 'Dr. Klein',
      );
      await vets.deleteByUuid(vetUuid);

      final ops = await db.pendingOpsDao.head();
      final vetOps = ops.where((o) => o.entityTable == 'vets').toList();
      expect(vetOps, hasLength(2),
          reason: 'create + soft-delete should both enqueue');
      final tombstone = vetOps.last;
      final payload =
          jsonDecode(tombstone.payloadJson) as Map<String, dynamic>;
      expect(payload['deletedAt'], isNotNull,
          reason: 'tombstone payload must carry the deleted_at timestamp');
    });

    test('createVet on local-only pet stays local — no enqueue',
        () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final vets = VetsRepository(db.vetsDao, db.petsDao, outbox: outbox);

      final petUuid = await pets.createPet(
        name: 'Solo',
        species: Species.dog,
        sex: Sex.male,
      );
      await vets.createVet(petUuid: petUuid, name: 'Dr. Klein');

      expect(await outbox.pendingCount(), 0);
    });
  });

  group('SyncOutbox FK resolution', () {
    test('vets enqueue rewrites petId (int) to the parent uuid string',
        () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final vets = VetsRepository(db.vetsDao, db.petsDao, outbox: outbox);

      final petUuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );
      await vets.createVet(petUuid: petUuid, name: 'Dr. Klein');

      final ops = await db.pendingOpsDao.head();
      final vetOp = ops.firstWhere((o) => o.entityTable == 'vets');
      final payload = jsonDecode(vetOp.payloadJson) as Map<String, dynamic>;
      // FK column keeps its key name — only the value type changes.
      // The push-side translator will rename to snake_case (`pet_id`).
      expect(payload['petId'], petUuid,
          reason: 'petId must be the parent pet\'s uuid, not local int');
      expect(payload['petId'], isA<String>());
    });
  });

  group('Backward compat', () {
    test('repos without outbox never touch pending_ops', () async {
      final db = newInMemoryDatabase();
      final repo = PetsRepository(db.petsDao); // no outbox

      final uuid = await repo.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );
      await repo.updatePet(
        uuid: uuid,
        name: 'Bello II',
        species: Species.dog,
        sex: Sex.male,
      );
      await repo.softDelete(uuid);

      final count = await db.pendingOpsDao.count();
      expect(count, 0);
    });
  });
}
