import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/supabase/current_user.dart';
import '../../sync/data/sync_outbox.dart';

/// Stamps every top-level local row whose `household_id` is still NULL
/// with a given household id + the current user id, and — when an
/// outbox is supplied — enqueues an upsert for each of the top-level
/// rows it just adopted so they actually make it to the cloud.
///
/// Idempotent: the WHERE clause excludes already-stamped rows, so a
/// repeat call after re-install (with a restored DB) is safe. Rows
/// stamped by an earlier call don't get re-enqueued because they
/// aren't in the pre-stamp uuid snapshot the second time around.
class HouseholdStamper {
  HouseholdStamper(this._db);

  final AppDatabase _db;

  /// Which sync-column tables get the stamp. The 13 listed here match
  /// the M2 guard test's `topLevelTables` plus a couple of helper
  /// tables (pet_weights, event_tags, medication_intakes) that hold
  /// data derived from a top-level entity but still need a
  /// household_id for future scoped queries. Not all of these push
  /// through the outbox — the enqueue step below picks only the ten
  /// tables the SyncOutbox knows FK mappings for.
  static const _stampedTables = <String>{
    'pets',
    'vets',
    'contacts',
    'appointments',
    'medications',
    'medication_intakes',
    'foods',
    'vaccinations',
    'insurances',
    'events',
    'event_tags',
    'pet_weights',
    'pet_documents',
    // M5 phase 1: nested attachment surfaces gained the M2 sync
    // columns and need the same first-login backfill treatment.
    'event_photos',
    'food_photos',
    'insurance_documents',
    'vaccination_documents',
    'pet_passport_documents',
  };

  /// Top-level entities the SyncOutbox pushes. Bootstrap-enqueue only
  /// enqueues these; helper tables (event_tags, pet_weights,
  /// medication_intakes) don't have a repo-side enqueue path yet and
  /// stay local-only until pull/push covers them explicitly.
  static const _syncedTables = <String>[
    'pets',
    'vets',
    'contacts',
    'appointments',
    'medications',
    'foods',
    'vaccinations',
    'insurances',
    'events',
    'pet_documents',
    'event_photos',
    'food_photos',
    'insurance_documents',
    'vaccination_documents',
    'pet_passport_documents',
  ];

  /// Runs the null-household stamp and, if an outbox is supplied,
  /// enqueues an upsert for every row that just got adopted. Returns
  /// how many rows were stamped and how many were enqueued.
  ///
  /// When [outbox] is null (tests, legacy call sites that only care
  /// about the stamp) the enqueue phase is skipped entirely.
  Future<StampResult> stampNullRows(
    String householdId, {
    SyncOutbox? outbox,
  }) async {
    final userId = currentUserId();

    // Phase 1: snapshot the uuids that are about to be stamped, per
    // table the outbox knows about. Skipped when there's no outbox to
    // hand them to.
    final targets = <_Target>[];
    if (outbox != null) {
      for (final table in _syncedTables) {
        final rows = await _db
            .customSelect(
              'SELECT uuid FROM $table WHERE household_id IS NULL',
            )
            .get();
        for (final r in rows) {
          targets.add(_Target(table, r.read<String>('uuid')));
        }
      }
    }

    // Phase 2: stamp all null rows in a single transaction so partial
    // failures roll back instead of leaving a mixed state.
    final tables = _resolveTables();
    final stamped = await _db.transaction<int>(() async {
      var t = 0;
      for (final table in tables) {
        t += await _stampTable(table, householdId, userId);
      }
      return t;
    });

    // Phase 3: enqueue each row from the snapshot. Fetch the fresh
    // row through the DAO so the payload includes the household_id we
    // just set, then hand off to the outbox — which runs the FK
    // resolver in turn (petId int → parent uuid string).
    if (outbox != null && targets.isNotEmpty) {
      for (final target in targets) {
        final payload = await _fetchPayload(target);
        if (payload == null) continue;
        await outbox.enqueueUpsert(
          entityTable: target.table,
          entityUuid: target.uuid,
          householdId: householdId,
          payload: payload,
        );
      }
    }

    return StampResult(stamped: stamped, enqueued: targets.length);
  }

  List<TableInfo<Table, dynamic>> _resolveTables() {
    return [
      for (final t in _db.allTables)
        if (_stampedTables.contains(t.actualTableName))
          t as TableInfo<Table, dynamic>,
    ];
  }

  Future<int> _stampTable<T extends Table, R>(
    TableInfo<T, R> table,
    String householdId,
    String? updatedBy,
  ) {
    // Two separate statements: SQLite's parameter binder rejects a bare
    // NULL literal for a typed slot, and Drift's `Variable<T>` requires
    // T extends Object. The updated_by column is nullable so on signed-
    // out installs we branch here to skip the binding entirely.
    if (updatedBy == null) {
      return _db.customUpdate(
        'UPDATE ${table.actualTableName} '
        'SET household_id = ? '
        'WHERE household_id IS NULL',
        variables: [Variable<String>(householdId)],
        updates: {table},
      );
    }
    return _db.customUpdate(
      'UPDATE ${table.actualTableName} '
      'SET household_id = ?, updated_by_user_id = ? '
      'WHERE household_id IS NULL',
      variables: [
        Variable<String>(householdId),
        Variable<String>(updatedBy),
      ],
      updates: {table},
    );
  }

  Future<Map<String, dynamic>?> _fetchPayload(_Target t) async {
    switch (t.table) {
      case 'pets':
        return (await _db.petsDao.getByUuid(t.uuid))?.toJson();
      case 'vets':
        return (await _db.vetsDao.getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'contacts':
        return (await _db.contactsDao.getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'appointments':
        return (await _db.appointmentsDao.getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'medications':
        return (await _db.medicationsDao.getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'foods':
        return (await _db.foodsDao.getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'vaccinations':
        return (await _db.vaccinationsDao.getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'insurances':
        return (await _db.insurancesDao.getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'events':
        return (await _db.eventsDao.getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'pet_documents':
        return (await _db.petDocumentsDao.getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'event_photos':
        return (await _db.eventPhotosDao.getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'food_photos':
        return (await _db.foodPhotosDao.getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'insurance_documents':
        return (await _db.insuranceDocumentsDao
                .getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'vaccination_documents':
        return (await _db.vaccinationDocumentsDao
                .getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
      case 'pet_passport_documents':
        return (await _db.petPassportDocumentsDao
                .getByUuidIncludingDeleted(t.uuid))
            ?.toJson();
    }
    return null;
  }
}

class StampResult {
  const StampResult({required this.stamped, required this.enqueued});
  final int stamped;
  final int enqueued;
}

class _Target {
  const _Target(this.table, this.uuid);
  final String table;
  final String uuid;
}
