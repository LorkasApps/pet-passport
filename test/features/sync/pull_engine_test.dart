import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/sync/data/pull_engine.dart';

import '../../helpers/database_helper.dart';
import '../../helpers/fake_cloud_api.dart';

/// Contract tests for the delta-pull loop. Only pets is wired for the
/// v1 apply layer; the other nine tables land in a follow-up commit.
/// The engine, cursor advance, LWW skip and household filter are all
/// generic enough to exercise here with just pets.
void main() {
  group('PullEngine — pets happy path', () {
    test('pulls a fresh remote row into the local DB', () async {
      final db = newInMemoryDatabase();
      final cloud = FakeCloudApi();
      cloud.seed('pets', {
        'id': 'p-1',
        'name': 'Bello',
        'species': Species.dog.index,
        'sex': Sex.male.index,
        'is_neutered': false,
        'created_at': DateTime.utc(2026, 7, 24, 10).toIso8601String(),
        'updated_at': DateTime.utc(2026, 7, 24, 10).toIso8601String(),
        'household_id': 'h-1',
      });

      final engine = PullEngine(db, cloud);
      final result = await engine.pullOnce(householdIds: ['h-1']);

      expect(result.applied, 1);
      expect(result.lwwSkipped, 0);
      final row = await db.petsDao.getByUuid('p-1');
      expect(row, isNotNull);
      expect(row!.name, 'Bello');
      expect(row.householdId, 'h-1');

      // Cursor advanced to the pulled row's updated_at. Compare via
      // millisSinceEpoch — Drift reads DateTime back as local-tz,
      // but the underlying instant is what matters.
      final cursor = await db.syncCursorsDao.get('pets');
      expect(
        cursor!.millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 24, 10).millisecondsSinceEpoch,
      );
    });

    test('household filter skips rows I do not belong to', () async {
      final db = newInMemoryDatabase();
      final cloud = FakeCloudApi();
      cloud.seed('pets', {
        'id': 'p-1',
        'name': 'Foreign',
        'species': Species.dog.index,
        'sex': Sex.male.index,
        'is_neutered': false,
        'created_at': DateTime.utc(2026, 7, 24).toIso8601String(),
        'updated_at': DateTime.utc(2026, 7, 24).toIso8601String(),
        'household_id': 'h-not-mine',
      });

      final result = await PullEngine(db, cloud)
          .pullOnce(householdIds: ['h-mine']);
      expect(result.applied, 0);
      expect(await db.petsDao.getByUuid('p-1'), isNull);
    });
  });

  group('PullEngine — LWW', () {
    test('skips a pulled row when local is fresher', () async {
      final db = newInMemoryDatabase();
      final pets = PetsRepository(db.petsDao, db);
      final uuid = await pets.createPet(
        name: 'LocalFresh',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );
      final localRow = await db.petsDao.getByUuid(uuid);
      // Craft an incoming row with an older updated_at than the local.
      final older =
          localRow!.updatedAt.subtract(const Duration(minutes: 5));

      final cloud = FakeCloudApi();
      cloud.seed('pets', {
        'id': uuid,
        'name': 'CloudStale',
        'species': Species.dog.index,
        'sex': Sex.male.index,
        'is_neutered': false,
        'created_at': localRow.createdAt.toUtc().toIso8601String(),
        'updated_at': older.toUtc().toIso8601String(),
        'household_id': 'h-1',
      });

      final result = await PullEngine(db, cloud)
          .pullOnce(householdIds: ['h-1']);
      expect(result.lwwSkipped, 1);
      expect(result.applied, 0);
      final row = await db.petsDao.getByUuid(uuid);
      expect(row!.name, 'LocalFresh',
          reason: 'local write must not be overwritten by a stale pull');
    });

    test('overwrites the local row when incoming is fresher', () async {
      final db = newInMemoryDatabase();
      final pets = PetsRepository(db.petsDao, db);
      final uuid = await pets.createPet(
        name: 'LocalStale',
        species: Species.dog,
        sex: Sex.male,
        householdId: 'h-1',
      );
      final localRow = await db.petsDao.getByUuid(uuid);
      final newer = localRow!.updatedAt.add(const Duration(minutes: 5));

      final cloud = FakeCloudApi();
      cloud.seed('pets', {
        'id': uuid,
        'name': 'CloudFresh',
        'species': Species.dog.index,
        'sex': Sex.male.index,
        'is_neutered': true,
        'created_at': localRow.createdAt.toUtc().toIso8601String(),
        'updated_at': newer.toUtc().toIso8601String(),
        'household_id': 'h-1',
      });

      final result = await PullEngine(db, cloud)
          .pullOnce(householdIds: ['h-1']);
      expect(result.applied, 1);
      final row = await db.petsDao.getByUuid(uuid);
      expect(row!.name, 'CloudFresh');
      expect(row.isNeutered, isTrue);
    });
  });

  group('PullEngine — delta cursor', () {
    test('second pull only sees rows newer than the cursor', () async {
      final db = newInMemoryDatabase();
      final cloud = FakeCloudApi();

      cloud.seed('pets', {
        'id': 'p-1',
        'name': 'A',
        'species': Species.dog.index,
        'sex': Sex.male.index,
        'is_neutered': false,
        'created_at': DateTime.utc(2026, 7, 24, 10).toIso8601String(),
        'updated_at': DateTime.utc(2026, 7, 24, 10).toIso8601String(),
        'household_id': 'h-1',
      });

      final engine = PullEngine(db, cloud);
      await engine.pullOnce(householdIds: ['h-1']);

      // Second run without any new remote changes → nothing applied.
      final second = await engine.pullOnce(householdIds: ['h-1']);
      expect(second.applied, 0);

      // Add a NEW cloud row. Only that one should come through.
      cloud.seed('pets', {
        'id': 'p-2',
        'name': 'B',
        'species': Species.dog.index,
        'sex': Sex.male.index,
        'is_neutered': false,
        'created_at': DateTime.utc(2026, 7, 24, 11).toIso8601String(),
        'updated_at': DateTime.utc(2026, 7, 24, 11).toIso8601String(),
        'household_id': 'h-1',
      });
      final third = await engine.pullOnce(householdIds: ['h-1']);
      expect(third.applied, 1);
    });
  });

  group('PullEngine — tombstones', () {
    test('a soft-deleted remote row lands with deleted_at set locally',
        () async {
      final db = newInMemoryDatabase();
      final cloud = FakeCloudApi();
      final now = DateTime.utc(2026, 7, 24, 12);
      cloud.seed('pets', {
        'id': 'p-1',
        'name': 'Doomed',
        'species': Species.dog.index,
        'sex': Sex.male.index,
        'is_neutered': false,
        'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'updated_at': now.toIso8601String(),
        'deleted_at': now.toIso8601String(),
        'household_id': 'h-1',
      });

      await PullEngine(db, cloud).pullOnce(householdIds: ['h-1']);
      // getByUuid on pets doesn't filter deleted, so we can inspect.
      final row = await db.petsDao.getByUuid('p-1');
      expect(row, isNotNull);
      expect(row!.deletedAt, isNotNull);
      // watchActivePets DOES filter — should not show it.
      final active = await db.petsDao.watchActivePets().first;
      expect(active, isEmpty);
    });
  });
}
