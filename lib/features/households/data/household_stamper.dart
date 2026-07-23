import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/supabase/current_user.dart';

/// Stamps every top-level local row whose `household_id` is still NULL
/// with a given household id + the current user id. Used at first login
/// so pre-cloud rows land inside the auto-created default household and
/// stop looking rootless.
///
/// Idempotent: the WHERE clause excludes already-stamped rows, so a
/// repeat call after re-install (with a restored DB) is safe. Rows with
/// a household_id set by another device stay untouched.
class HouseholdStamper {
  HouseholdStamper(this._db);

  final AppDatabase _db;

  Future<int> stampNullRows(String householdId) async {
    final userId = currentUserId();
    // Do the writes in a single transaction so a partial run either
    // fully applies or fully rolls back — leaving a mixed state (some
    // rows stamped, others not) would silently split future queries.
    return _db.transaction<int>(() async {
      var total = 0;
      total += await _stampTable(_db.pets, householdId, userId);
      total += await _stampTable(_db.vets, householdId, userId);
      total += await _stampTable(_db.contacts, householdId, userId);
      total += await _stampTable(_db.appointments, householdId, userId);
      total += await _stampTable(_db.medications, householdId, userId);
      total += await _stampTable(_db.medicationIntakes, householdId, userId);
      total += await _stampTable(_db.foods, householdId, userId);
      total += await _stampTable(_db.vaccinations, householdId, userId);
      total += await _stampTable(_db.insurances, householdId, userId);
      total += await _stampTable(_db.events, householdId, userId);
      total += await _stampTable(_db.eventTags, householdId, userId);
      total += await _stampTable(_db.petWeights, householdId, userId);
      total += await _stampTable(_db.petDocuments, householdId, userId);
      return total;
    });
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
}
