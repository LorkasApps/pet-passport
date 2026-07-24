import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/sync/data/sync_outbox.dart';

import '../../helpers/database_helper.dart';

void main() {
  group('SyncOutbox', () {
    test('enqueue writes one pending op with the given payload', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);

      await outbox.enqueueUpsert(
        entityTable: 'pets',
        entityUuid: 'pet-1',
        householdId: 'h-1',
        payload: {'name': 'Bello', 'updated_at': '2026-07-23T14:00:00Z'},
      );

      expect(await outbox.pendingCount(), 1);
      final ops = await db.pendingOpsDao.head();
      expect(ops.single.entityTable, 'pets');
      expect(ops.single.entityUuid, 'pet-1');
      expect(ops.single.householdId, 'h-1');
      expect(ops.single.opType, 'upsert');
      final decoded =
          jsonDecode(ops.single.payloadJson) as Map<String, dynamic>;
      expect(decoded['name'], 'Bello');
    });

    test('markSuccess removes the op from the queue', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);

      await outbox.enqueueUpsert(
        entityTable: 'pets',
        entityUuid: 'pet-1',
        householdId: 'h-1',
        payload: const {'name': 'Bello'},
      );
      final op = (await db.pendingOpsDao.head()).single;
      await db.pendingOpsDao.markSuccess(op.id);
      expect(await outbox.pendingCount(), 0);
    });

    test('markFailure keeps the op and bumps attempts', () async {
      final db = newInMemoryDatabase();
      final outbox = SyncOutbox(db);

      await outbox.enqueueUpsert(
        entityTable: 'pets',
        entityUuid: 'pet-1',
        householdId: 'h-1',
        payload: const {'name': 'Bello'},
      );
      final op = (await db.pendingOpsDao.head()).single;
      await db.pendingOpsDao.incrementAttempts(op.id);
      await db.pendingOpsDao
          .markFailure(op.id, 'net down', DateTime(2026, 7, 23));

      final again = (await db.pendingOpsDao.head()).single;
      expect(again.attempts, 1);
      expect(again.lastError, 'net down');
      expect(await outbox.pendingCount(), 1);
    });
  });

  group('SyncCursorsDao', () {
    test('set + get + reset round-trip', () async {
      final db = newInMemoryDatabase();
      final cursors = db.syncCursorsDao;

      expect(await cursors.get('pets'), isNull);
      final at = DateTime(2026, 7, 23, 14);
      await cursors.set('pets', at);
      expect(await cursors.get('pets'), at);

      // Overwrite semantics — no separate history row.
      final later = DateTime(2026, 7, 24, 9);
      await cursors.set('pets', later);
      expect(await cursors.get('pets'), later);

      await cursors.reset('pets');
      expect(await cursors.get('pets'), isNull);
    });
  });
}
