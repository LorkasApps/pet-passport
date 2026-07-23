import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sync_cursors_table.dart';

part 'sync_cursors_dao.g.dart';

@DriftAccessor(tables: [SyncCursors])
class SyncCursorsDao extends DatabaseAccessor<AppDatabase>
    with _$SyncCursorsDaoMixin {
  SyncCursorsDao(super.db);

  Future<DateTime?> get(String entity) async {
    final row = await (select(syncCursors)
          ..where((c) => c.entity.equals(entity)))
        .getSingleOrNull();
    return row?.lastPulledAt;
  }

  Future<void> set(String entity, DateTime lastPulledAt) async {
    await into(syncCursors).insertOnConflictUpdate(
      SyncCursorsCompanion.insert(
        entity: entity,
        lastPulledAt: lastPulledAt,
      ),
    );
  }

  Future<int> reset(String entity) {
    return (delete(syncCursors)..where((c) => c.entity.equals(entity)))
        .go();
  }
}
