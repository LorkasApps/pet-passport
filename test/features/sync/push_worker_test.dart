import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/sync/data/push_worker.dart';
import 'package:pet_passport/features/sync/data/sync_outbox.dart';

import '../../helpers/database_helper.dart';
import '../../helpers/fake_cloud_api.dart';

/// Contract tests for the drain loop. Uses real Drift + real repos on
/// the local side so the tests double as an integration check of the
/// enqueue → drain path, and a FakeCloudApi on the remote side so we
/// stay deterministic.
void main() {
  group('PushWorker.drainOnce — happy path', () {
    test('drains one enqueued upsert and clears the outbox', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db.pendingOpsDao);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final cloud = FakeCloudApi();
      final worker = PushWorker(db.pendingOpsDao, cloud);

      final uuid = await pets.createPet(
        name: 'Bello',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );

      final result = await worker.drainOnce();

      expect(result.sent, 1);
      expect(result.inspected, 1);
      expect(await db.pendingOpsDao.count(), 0);
      final row = cloud.find('pets', uuid);
      expect(row, isNotNull);
      expect(row!['uuid'], uuid);
      expect(row['name'], 'Bello');
      expect(row['householdId'], 'h-1');
      expect(row.containsKey('id'), isFalse,
          reason: 'local autoincrement id must be stripped before push');
    });

    test('drains ops in FIFO order', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db.pendingOpsDao);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final cloud = FakeCloudApi();
      final worker = PushWorker(db.pendingOpsDao, cloud);

      final a = await pets.createPet(
        name: 'A',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );
      final b = await pets.createPet(
        name: 'B',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );

      await worker.drainOnce();

      expect(cloud.calls.map((c) => c.uuid).toList(), [a, b]);
    });

    test('empty queue drains to a zero-count result without error',
        () async {
      final db = newInMemoryDatabase();
      final cloud = FakeCloudApi();
      final worker = PushWorker(db.pendingOpsDao, cloud);

      final result = await worker.drainOnce();

      expect(result.inspected, 0);
      expect(result.sent, 0);
      expect(cloud.calls, isEmpty);
    });

    test('tombstone (soft-delete) propagates to the cloud', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db.pendingOpsDao);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final cloud = FakeCloudApi();
      final worker = PushWorker(db.pendingOpsDao, cloud);

      final uuid = await pets.createPet(
        name: 'Doomed',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );
      await pets.softDelete(uuid);

      await worker.drainOnce();

      final row = cloud.find('pets', uuid);
      expect(row, isNotNull);
      expect(row!['deletedAt'], isNotNull);
      expect(await db.pendingOpsDao.count(), 0);
    });
  });

  group('PushWorker.drainOnce — retry semantics', () {
    test('retryable failure keeps the op and bumps attempts', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db.pendingOpsDao);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final cloud = FakeCloudApi()..queueRetryable('net glitch');
      final worker = PushWorker(db.pendingOpsDao, cloud);

      await pets.createPet(
        name: 'A',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );

      final result = await worker.drainOnce();
      expect(result.retried, 1);
      expect(result.sent, 0);
      final remaining = await db.pendingOpsDao.head();
      expect(remaining, hasLength(1));
      expect(remaining.single.attempts, 1);
      expect(remaining.single.lastError, 'net glitch');
    });

    test('backoff skips a freshly-failed op on immediate re-drain',
        () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db.pendingOpsDao);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final cloud = FakeCloudApi()..queueRetryable('first fail');
      // Freeze clock so lastAttemptAt + backoff comparison is
      // deterministic.
      final now = DateTime(2026, 7, 24, 12);
      final worker = PushWorker(db.pendingOpsDao, cloud, now: () => now);

      await pets.createPet(
        name: 'A',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );

      await worker.drainOnce();
      // Immediate second drain — the retryable op has attempts=1 which
      // maps to a 500ms backoff. Zero elapsed time → still parked.
      final result = await worker.drainOnce();
      expect(result.inspected, 1);
      expect(result.sent, 0);
      expect(result.retried, 0);
      expect(result.skippedBackoff, 1);
    });

    test('after backoff elapses the op is re-attempted', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db.pendingOpsDao);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final cloud = FakeCloudApi()..queueRetryable('first fail');

      var now = DateTime(2026, 7, 24, 12);
      final worker =
          PushWorker(db.pendingOpsDao, cloud, now: () => now);

      await pets.createPet(
        name: 'A',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );

      await worker.drainOnce();
      // Advance past the 500ms window. Second drain should retry —
      // FakeCloudApi has no more queued failures, so it succeeds.
      now = now.add(const Duration(seconds: 1));
      final result = await worker.drainOnce();
      expect(result.sent, 1);
      expect(await db.pendingOpsDao.count(), 0);
    });
  });

  group('PushWorker.drainOnce — terminal failures', () {
    test('terminal failure parks the op with error, no retry', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db.pendingOpsDao);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final cloud = FakeCloudApi()..queueTerminal('schema mismatch');
      final worker = PushWorker(db.pendingOpsDao, cloud);

      await pets.createPet(
        name: 'A',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );

      final result = await worker.drainOnce();
      expect(result.terminal, 1);
      expect(result.sent, 0);
      final row = (await db.pendingOpsDao.head()).single;
      expect(row.attempts, 1);
      expect(row.lastError, startsWith('terminal:'));
    });
  });

  group('PushWorker.drainOnce — single-flight', () {
    test('overlapping drainOnce calls share the same in-flight future',
        () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db.pendingOpsDao);
      final pets = PetsRepository(db.petsDao, outbox: outbox);
      final cloud = FakeCloudApi();
      final worker = PushWorker(db.pendingOpsDao, cloud);

      await pets.createPet(
        name: 'A',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );

      final a = worker.drainOnce();
      final b = worker.drainOnce();
      expect(identical(a, b), isTrue,
          reason: 'a second call while inflight must reuse the future');
      await Future.wait([a, b]);
    });
  });
}
