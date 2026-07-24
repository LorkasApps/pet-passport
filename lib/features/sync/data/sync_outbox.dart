import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

/// High-level façade for enqueuing cloud-sync operations. Repositories
/// call this after every write on a top-level entity; the push engine
/// drains the queue asynchronously.
///
/// Soft-delete note: because deleted rows carry `deleted_at != null`
/// and their fields are otherwise intact, we don't need a separate
/// `delete` op type — a soft-delete write is just an `upsert` whose
/// payload has the tombstone. The `op_type` column stays in the schema
/// as an escape hatch for future hard-delete semantics.
///
/// FK resolution: local Drift tables carry int foreign keys
/// (`petId`, `vetId`, `contactId`, `prescribedByVetId`) that mean
/// nothing on the cloud side — every cloud table uses uuid PKs. The
/// enqueue path rewrites those keys into their uuid-string equivalents
/// before the payload lands in `pending_ops`. Repos hand us the raw
/// `row.toJson()`; the transformation lives here so every repo doesn't
/// have to re-implement it.
class SyncOutbox {
  SyncOutbox(this._db);

  final AppDatabase _db;

  Future<void> enqueueUpsert({
    required String entityTable,
    required String entityUuid,
    required String? householdId,
    required Map<String, dynamic> payload,
  }) async {
    final resolved = await _resolveForeignKeys(entityTable, payload);
    await _db.pendingOpsDao.enqueue(PendingOpsCompanion.insert(
      opType: 'upsert',
      entityTable: entityTable,
      entityUuid: entityUuid,
      householdId: Value(householdId),
      payloadJson: jsonEncode(resolved),
      queuedAt: DateTime.now(),
    ));
  }

  Future<int> pendingCount() => _db.pendingOpsDao.count();

  Stream<int> watchPendingCount() => _db.pendingOpsDao.watchCount();

  /// Rewrite `<parent>Id: int` keys into `<parent>Id: <parentUuid>`
  /// (String) using the local DAOs. The key name stays the same — only
  /// the value type changes. The push-side translator then handles the
  /// eventual camelCase → snake_case rename to match the cloud column
  /// (e.g. `petId` → `pet_id`).
  ///
  /// If the parent row is gone (e.g. hard-deleted locally before the
  /// drain caught up), we drop the key entirely rather than pushing an
  /// int. The server will reject that anyway; better to fail cheaply
  /// with a null FK than to burn retries on a doomed payload.
  Future<Map<String, dynamic>> _resolveForeignKeys(
    String table,
    Map<String, dynamic> payload,
  ) async {
    final mappings = _fkMap[table];
    if (mappings == null || mappings.isEmpty) return payload;

    final out = Map<String, dynamic>.from(payload);
    for (final fk in mappings) {
      final val = out[fk.localKey];
      if (val is! int) continue; // already resolved or null
      final uuid = await _lookupUuid(fk.parentTable, val);
      if (uuid == null) {
        out.remove(fk.localKey);
      } else {
        out[fk.localKey] = uuid;
      }
    }
    return out;
  }

  Future<String?> _lookupUuid(String table, int id) async {
    switch (table) {
      case 'pets':
        return (await _db.petsDao.getById(id))?.uuid;
      case 'vets':
        return (await _db.vetsDao.getById(id))?.uuid;
      case 'contacts':
        return (await _db.contactsDao.getById(id))?.uuid;
    }
    return null;
  }
}

/// Per-child-table list of local FK columns that need int→uuid
/// resolution before push. Hand-maintained instead of derived: schema
/// changes should trigger a deliberate update here.
const _fkMap = <String, List<_Fk>>{
  'vets': [_Fk('petId', 'pets')],
  'contacts': [_Fk('petId', 'pets')],
  'appointments': [
    _Fk('petId', 'pets'),
    _Fk('vetId', 'vets'),
    _Fk('contactId', 'contacts'),
  ],
  'medications': [
    _Fk('petId', 'pets'),
    _Fk('prescribedByVetId', 'vets'),
  ],
  'foods': [_Fk('petId', 'pets')],
  'vaccinations': [
    _Fk('petId', 'pets'),
    _Fk('vetId', 'vets'),
  ],
  'insurances': [_Fk('petId', 'pets')],
  'events': [_Fk('petId', 'pets')],
  'pet_documents': [_Fk('petId', 'pets')],
};

class _Fk {
  const _Fk(this.localKey, this.parentTable);
  final String localKey;
  final String parentTable;
}
