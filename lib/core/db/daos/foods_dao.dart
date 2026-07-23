import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/food_photos_table.dart';
import '../tables/foods_table.dart';

part 'foods_dao.g.dart';

@DriftAccessor(tables: [Foods, FoodPhotos])
class FoodsDao extends DatabaseAccessor<AppDatabase> with _$FoodsDaoMixin {
  FoodsDao(super.db);

  Stream<List<FoodRow>> watchForPet(int petId) {
    return (select(foods)
          ..where((f) => f.petId.equals(petId))
          ..orderBy([
            (f) => OrderingTerm.desc(f.isActive),
            (f) => OrderingTerm.asc(f.name),
          ]))
        .watch();
  }

  Stream<List<FoodRow>> watchActiveForPet(int petId) {
    return (select(foods)
          ..where((f) => f.petId.equals(petId) & f.isActive.equals(true))
          ..orderBy([(f) => OrderingTerm.asc(f.name)]))
        .watch();
  }

  Future<FoodRow?> getByUuid(String uuid) {
    return (select(foods)..where((f) => f.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Stream<FoodRow?> watchByUuid(String uuid) {
    return (select(foods)..where((f) => f.uuid.equals(uuid)))
        .watchSingleOrNull();
  }

  Future<int> insertFood(FoodsCompanion companion) {
    return into(foods).insert(companion);
  }

  Future<bool> updateFood(FoodRow row) {
    return update(foods).replace(row);
  }

  Future<int> deleteByUuid(String uuid) {
    return (delete(foods)..where((f) => f.uuid.equals(uuid))).go();
  }

  /// Active foods with reminders enabled — used by boot reschedule to
  /// re-arm feeding notifications after cold start / TZ change.
  Future<List<FoodRow>> getAllActiveWithReminders() {
    return (select(foods)
          ..where((f) =>
              f.isActive.equals(true) & f.remindersEnabled.equals(true)))
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

  Future<int> deletePhotoByUuid(String uuid) {
    return (delete(foodPhotos)..where((p) => p.uuid.equals(uuid))).go();
  }

  Future<int> deletePhotosForFood(int foodId) {
    return (delete(foodPhotos)..where((p) => p.foodId.equals(foodId))).go();
  }
}
