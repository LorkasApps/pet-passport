import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
import '../database.dart';
import '../tables/food_photos_table.dart';

part 'food_photos_dao.g.dart';

@DriftAccessor(tables: [FoodPhotos])
class FoodPhotosDao extends DatabaseAccessor<AppDatabase>
    with _$FoodPhotosDaoMixin {
  FoodPhotosDao(super.db);

  Stream<List<FoodPhotoRow>> watchForFood(int foodId) {
    return (select(foodPhotos)
          ..where((p) => p.foodId.equals(foodId) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Future<FoodPhotoRow?> getByUuid(String uuid) {
    return (select(foodPhotos)
          ..where((p) => p.uuid.equals(uuid) & p.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<FoodPhotoRow?> getByUuidIncludingDeleted(String uuid) {
    return (select(foodPhotos)..where((p) => p.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<int> insertPhoto(FoodPhotosCompanion companion) {
    return into(foodPhotos).insert(companion);
  }

  Future<bool> updatePhoto(FoodPhotoRow row) {
    return update(foodPhotos).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(foodPhotos)..where((p) => p.uuid.equals(uuid)))
        .write(FoodPhotosCompanion(
      deletedAt: Value(deletedAt),
      updatedAt: Value(deletedAt),
      updatedByUserId: Value(currentUserId()),
    ));
  }

  Future<int> deleteAllForFood(int foodId) {
    return (delete(foodPhotos)..where((p) => p.foodId.equals(foodId))).go();
  }

  Future<int> countForFood(int foodId) async {
    final row = await (selectOnly(foodPhotos)
          ..addColumns([foodPhotos.id.count()])
          ..where(foodPhotos.foodId.equals(foodId) &
              foodPhotos.deletedAt.isNull()))
        .getSingle();
    return row.read(foodPhotos.id.count()) ?? 0;
  }
}
