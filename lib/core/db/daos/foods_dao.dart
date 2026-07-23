import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
import '../database.dart';
import '../tables/food_photos_table.dart';
import '../tables/foods_table.dart';

part 'foods_dao.g.dart';

@DriftAccessor(tables: [Foods, FoodPhotos])
class FoodsDao extends DatabaseAccessor<AppDatabase> with _$FoodsDaoMixin {
  FoodsDao(super.db);

  Stream<List<FoodRow>> watchForPet(int petId) {
    return (select(foods)
          ..where((f) => f.petId.equals(petId) & f.deletedAt.isNull())
          ..orderBy([
            (f) => OrderingTerm.desc(f.isActive),
            (f) => OrderingTerm.asc(f.name),
          ]))
        .watch();
  }

  Stream<List<FoodRow>> watchActiveForPet(int petId) {
    return (select(foods)
          ..where((f) => f.petId.equals(petId) & f.isActive.equals(true) & f.deletedAt.isNull())
          ..orderBy([(f) => OrderingTerm.asc(f.name)]))
        .watch();
  }

  Future<FoodRow?> getByUuid(String uuid) {
    return (select(foods)..where((f) => f.uuid.equals(uuid) & f.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<FoodRow?> getByUuidIncludingDeleted(String uuid) {
    return (select(foods)..where((f) => f.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Stream<FoodRow?> watchByUuid(String uuid) {
    return (select(foods)..where((f) => f.uuid.equals(uuid) & f.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<int> insertFood(FoodsCompanion companion) {
    return into(foods).insert(companion);
  }

  Future<bool> updateFood(FoodRow row) {
    return update(foods).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(foods)..where((f) => f.uuid.equals(uuid)))
        .write(FoodsCompanion(
          deletedAt: Value(deletedAt),
          updatedByUserId: Value(currentUserId()),
        ));
  }

  /// Active foods with reminders enabled — used by boot reschedule to
  /// re-arm feeding notifications after cold start / TZ change.
  Future<List<FoodRow>> getAllActiveWithReminders() {
    return (select(foods)
          ..where((f) =>
              f.isActive.equals(true) & f.remindersEnabled.equals(true) & f.deletedAt.isNull()))
        .get();
  }

  // --- photos ---

  Stream<List<FoodPhotoRow>> watchPhotosForFood(int foodId) {
    return (select(foodPhotos)
          ..where((p) => p.foodId.equals(foodId))
          ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
        .watch();
  }

  Future<FoodPhotoRow?> getPhotoByUuid(String uuid) {
    return (select(foodPhotos)..where((p) => p.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<int> insertPhoto(FoodPhotosCompanion companion) {
    return into(foodPhotos).insert(companion);
  }

  Future<bool> updatePhoto(FoodPhotoRow row) {
    return update(foodPhotos).replace(row);
  }

  Future<int> deletePhotoByUuid(String uuid) {
    return (delete(foodPhotos)..where((p) => p.uuid.equals(uuid))).go();
  }

  Future<int> deletePhotosForFood(int foodId) {
    return (delete(foodPhotos)..where((p) => p.foodId.equals(foodId))).go();
  }
}
