import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/sync/data/pull_engine.dart';
import 'package:pet_passport/features/sync/data/realtime_engine.dart';
import 'package:pet_passport/features/sync/data/realtime_source.dart';

import '../../helpers/database_helper.dart';
import '../../helpers/fake_cloud_api.dart';
import '../../helpers/fake_realtime_source.dart';

/// The engine is a thin dispatcher — the meaningful logic lives in
/// PullEngine.applyRow which is already covered. Tests here verify:
/// * subscriptions are established per top-level table,
/// * an incoming change lands in the local DB,
/// * disconnect events surface on the status + onDisconnect streams,
/// * stop() removes every subscription (no leaks on scope-change).
void main() {
  group('RealtimeEngine', () {
    test('start subscribes to every top-level table', () async {
      final db = newInMemoryDatabase();
      final source = FakeRealtimeSource();
      final pull = PullEngine(db, FakeCloudApi());
      final engine = RealtimeEngine(source, pull);

      await engine.start(householdIds: ['h-1']);

      // 15 sync tables — 10 top-level + 5 nested attachment
      // surfaces (see RealtimeEngine._tables).
      expect(source.activeCount, 15);
      expect(engine.activeSubscriptionCount, 15);
    });

    test('start with an empty household set stays idle', () async {
      final db = newInMemoryDatabase();
      final source = FakeRealtimeSource();
      final pull = PullEngine(db, FakeCloudApi());
      final engine = RealtimeEngine(source, pull);

      await engine.start(householdIds: const []);
      expect(source.activeCount, 0);
    });

    test('an emitted INSERT change lands in the local DB', () async {
      final db = newInMemoryDatabase();
      final source = FakeRealtimeSource();
      final pull = PullEngine(db, FakeCloudApi());
      final engine = RealtimeEngine(source, pull);

      await engine.start(householdIds: ['h-1']);

      final at = DateTime.utc(2026, 7, 24, 12);
      source.emit(RealtimeChange(
        table: 'pets',
        type: RealtimeChangeType.insert,
        newRow: {
          'id': 'p-1',
          'name': 'Bello',
          'species': Species.dog.index,
          'sex': Sex.male.index,
          'is_neutered': false,
          'created_at': at.toIso8601String(),
          'updated_at': at.toIso8601String(),
          'household_id': 'h-1',
        },
      ));
      // The applyRow call is awaited inside _handle but the emit
      // itself doesn't await. Yield once to let the microtask land.
      await Future<void>.delayed(Duration.zero);

      final row = await db.petsDao.getByUuid('p-1');
      expect(row, isNotNull);
      expect(row!.name, 'Bello');
    });

    test('UPDATE with deleted_at set applies as tombstone', () async {
      final db = newInMemoryDatabase();
      final source = FakeRealtimeSource();
      final pull = PullEngine(db, FakeCloudApi());
      final engine = RealtimeEngine(source, pull);
      await engine.start(householdIds: ['h-1']);

      final at = DateTime.utc(2026, 7, 24, 12);
      source.emit(RealtimeChange(
        table: 'pets',
        type: RealtimeChangeType.update,
        newRow: {
          'id': 'p-1',
          'name': 'Doomed',
          'species': Species.dog.index,
          'sex': Sex.male.index,
          'is_neutered': false,
          'created_at': at.subtract(const Duration(hours: 1)).toIso8601String(),
          'updated_at': at.toIso8601String(),
          'deleted_at': at.toIso8601String(),
          'household_id': 'h-1',
        },
      ));
      await Future<void>.delayed(Duration.zero);

      final row = await db.petsDao.getByUuid('p-1');
      expect(row?.deletedAt, isNotNull);
      final active = await db.petsDao.watchActivePets().first;
      expect(active, isEmpty);
    });

    test('disconnect surfaces on status + onDisconnect streams',
        () async {
      final db = newInMemoryDatabase();
      final source = FakeRealtimeSource();
      final pull = PullEngine(db, FakeCloudApi());
      final engine = RealtimeEngine(source, pull);
      addTearDown(engine.dispose);

      final statusEvents = <RealtimeStatus>[];
      final disconnects = <void>[];
      engine.status.listen(statusEvents.add);
      engine.onDisconnect.listen(disconnects.add);

      await engine.start(householdIds: ['h-1']);
      source.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(statusEvents, contains(RealtimeStatus.connected));
      expect(statusEvents, contains(RealtimeStatus.disconnected));
      expect(disconnects.length, greaterThanOrEqualTo(1));
    });

    test('stop removes every subscription', () async {
      final db = newInMemoryDatabase();
      final source = FakeRealtimeSource();
      final pull = PullEngine(db, FakeCloudApi());
      final engine = RealtimeEngine(source, pull);

      await engine.start(householdIds: ['h-1']);
      expect(source.activeCount, 15);

      engine.stop();
      expect(source.activeCount, 0);
      expect(engine.activeSubscriptionCount, 0);
    });

    test('restart on household-set change replaces subscriptions',
        () async {
      final db = newInMemoryDatabase();
      final source = FakeRealtimeSource();
      final pull = PullEngine(db, FakeCloudApi());
      final engine = RealtimeEngine(source, pull);

      await engine.start(householdIds: ['h-1']);
      final firstCount = source.activeCount;

      await engine.start(householdIds: ['h-1', 'h-2']);
      // Old subs disposed, new ones opened. Count stays at 10 (one
      // per table).
      expect(source.activeCount, firstCount);
    });
  });
}
