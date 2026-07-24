import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../appointments/domain/appointment_enums.dart';
import '../../contacts/domain/contact_enums.dart';
import '../../diet/domain/food_enums.dart';
import '../../medications/domain/medication_enums.dart';
import '../../pets/domain/pet_enums.dart';
import '../../protocol/domain/event_enums.dart';
import 'cloud_api.dart';
import 'supabase_cloud_api.dart' show fromCloudShape;

/// Known cursor-race limitation of this v1 pull:
///
/// Device A pulls and advances its cursor to max(updated_at seen) = T.
/// Device B is offline; pushes a row later with a client-stamped
/// updated_at = T' where T' < T (clock skew, or B's write happened
/// BEFORE A's last write chronologically but B was late to push).
/// Row lands in the cloud with updated_at = T' < T. On A's next
/// pull, `updated_at > T` never matches it — A never sees B's row.
///
/// Real fix: server-side monotonic sequence column
/// (`pulled_seq bigserial`, or `clock_timestamp()` on write via
/// trigger) that clients cursor on instead of client-writable
/// `updated_at`. Deferred until M4 Realtime lands — realtime push
/// makes this race window shrink to essentially zero and covers the
/// main "did I miss anything" concern without a schema change.
///
/// Delta-pull engine. For every top-level table it:
///
///   1. reads the persisted cursor (`sync_cursors`),
///   2. fetches rows with `updated_at > cursor` from the cloud in
///      pages of 500,
///   3. for each row: reverse-shape to local Drift keys, resolve
///      incoming uuid FKs to local int ids, LWW-check against the
///      existing local row, insert-or-update via the DAO,
///   4. advances the cursor to the max updated_at seen in the page.
///
/// Applies changes via the DAOs, NOT via the repos — repo writes go
/// through the outbox and would re-enqueue pulled rows into an
/// infinite loop.
///
/// Table order matters: children hold uuid FKs to parents. Pull pets
/// (and any other parentless tables) before their children so the
/// FK-resolver step below has something to look up.
class PullEngine {
  PullEngine(this._db, this._cloud, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final CloudApi _cloud;
  // ignore: unused_field
  final DateTime Function() _now;

  static const _tablesInOrder = <String>[
    'pets',
    'vets',
    'contacts',
    'foods',
    'insurances',
    'events',
    'pet_documents',
    // vaccinations & medications reference vets → after vets.
    'vaccinations',
    'medications',
    // appointments reference pets + vets + contacts → after all three.
    'appointments',
    // Nested attachment tables — must come after their respective parents.
    'event_photos',       // after events
    'food_photos',        // after foods
    'insurance_documents',
    'vaccination_documents',
    'pet_passport_documents',
  ];

  Future<PullResult> pullOnce({required List<String> householdIds}) async {
    if (householdIds.isEmpty) {
      return const PullResult(applied: 0, lwwSkipped: 0, missingParent: 0);
    }
    var applied = 0;
    var skipped = 0;
    var missingParent = 0;
    for (final table in _tablesInOrder) {
      final r = await _pullTable(table, householdIds);
      applied += r.applied;
      skipped += r.lwwSkipped;
      missingParent += r.missingParent;
    }
    return PullResult(
      applied: applied,
      lwwSkipped: skipped,
      missingParent: missingParent,
    );
  }

  Future<PullResult> _pullTable(
    String table,
    List<String> householdIds,
  ) async {
    var applied = 0;
    var skipped = 0;
    var missing = 0;
    var since = await _db.syncCursorsDao.get(table);
    while (true) {
      final page = await _cloud.fetchChangesSince(
        table: table,
        since: since,
        householdIds: householdIds,
      );
      if (page.rows.isEmpty) break;

      for (final row in page.rows) {
        final outcome = await applyRow(table, row);
        switch (outcome) {
          case RealtimeApplyOutcome.wrote:
            applied++;
          case RealtimeApplyOutcome.lwwSkipped:
            skipped++;
          case RealtimeApplyOutcome.missingParent:
            missing++;
        }
      }

      // Advance the cursor to the max updated_at we've now processed.
      // Comparing via DateTime.parse handles ISO-8601 exactly; we
      // could compare strings lexicographically too, but going
      // through DateTime keeps this readable.
      final maxUa = page.rows
          .map((r) => DateTime.parse(r['updated_at'] as String))
          .reduce((a, b) => a.isAfter(b) ? a : b);
      await _db.syncCursorsDao.set(table, maxUa);
      since = maxUa;

      if (!page.maybeMore) break;
    }
    return PullResult(
      applied: applied,
      lwwSkipped: skipped,
      missingParent: missing,
    );
  }

  /// Apply one cloud-shape row (as returned by fetchChangesSince or a
  /// postgres_changes payload) to the local DB. Reverse-shape → FK
  /// resolve → LWW check → upsert. Extracted so the realtime engine
  /// can reuse the exact same code path a delta pull uses.
  Future<RealtimeApplyOutcome> applyRow(
    String table,
    Map<String, dynamic> cloudRow,
  ) async {
    final local = fromCloudShape(cloudRow);
    final resolved = await _resolveIncomingFks(table, local);
    if (resolved == null) return RealtimeApplyOutcome.missingParent;
    final outcome = await _apply(table, resolved);
    switch (outcome) {
      case _ApplyOutcome.wrote:
        return RealtimeApplyOutcome.wrote;
      case _ApplyOutcome.lwwSkipped:
        return RealtimeApplyOutcome.lwwSkipped;
    }
  }

  /// Turn incoming uuid-FKs (`petId: "abc-uuid"`) into local int ids
  /// (`petId: 3`) by looking each parent up in the corresponding DAO.
  /// Returns null when a referenced parent isn't present locally —
  /// caller counts it as `missingParent` and moves on. On the next
  /// pull the child comes again (cursor didn't advance past its
  /// updated_at? Actually it DID — see note below); a future retry
  /// mechanism can pick these up.
  ///
  /// NOTE on cursor + missing parent: because we advance the cursor
  /// unconditionally, a row we skip here won't reappear on the next
  /// pull. That's a known limitation of the v1 pull loop — full
  /// resync from cursor=null recovers. Realtime (M4) should hit
  /// parents first anyway, so the window is small.
  Future<Map<String, dynamic>?> _resolveIncomingFks(
    String table,
    Map<String, dynamic> local,
  ) async {
    final fks = _incomingFkMap[table];
    if (fks == null || fks.isEmpty) return local;
    final out = Map<String, dynamic>.from(local);
    for (final fk in fks) {
      final val = out[fk.localKey];
      if (val == null) continue;
      if (val is int) continue; // already resolved
      if (val is! String) continue;
      final localId = await _lookupLocalId(fk.parentTable, val);
      if (localId == null) {
        // Required FK missing → drop the row.
        if (fk.required) return null;
        // Optional FK missing → keep the row, drop the reference.
        out[fk.localKey] = null;
      } else {
        out[fk.localKey] = localId;
      }
    }
    return out;
  }

  Future<int?> _lookupLocalId(String parentTable, String uuid) async {
    switch (parentTable) {
      case 'pets':
        return (await _db.petsDao.getByUuid(uuid))?.id;
      case 'vets':
        return (await _db.vetsDao.getByUuidIncludingDeleted(uuid))?.id;
      case 'contacts':
        return (await _db.contactsDao.getByUuidIncludingDeleted(uuid))?.id;
      case 'events':
        return (await _db.eventsDao.getByUuidIncludingDeleted(uuid))?.id;
      case 'foods':
        return (await _db.foodsDao.getByUuidIncludingDeleted(uuid))?.id;
      case 'insurances':
        return (await _db.insurancesDao.getByUuidIncludingDeleted(uuid))?.id;
      case 'vaccinations':
        return (await _db.vaccinationsDao.getByUuidIncludingDeleted(uuid))?.id;
    }
    return null;
  }

  Future<_ApplyOutcome> _apply(
    String table,
    Map<String, dynamic> row,
  ) async {
    switch (table) {
      case 'pets':
        return _applyPets(row);
      case 'vets':
        return _applyVets(row);
      case 'contacts':
        return _applyContacts(row);
      case 'foods':
        return _applyFoods(row);
      case 'insurances':
        return _applyInsurances(row);
      case 'events':
        return _applyEvents(row);
      case 'pet_documents':
        return _applyPetDocuments(row);
      case 'vaccinations':
        return _applyVaccinations(row);
      case 'medications':
        return _applyMedications(row);
      case 'appointments':
        return _applyAppointments(row);
      case 'event_photos':
        return _applyEventPhotos(row);
      case 'food_photos':
        return _applyFoodPhotos(row);
      case 'insurance_documents':
        return _applyInsuranceDocuments(row);
      case 'vaccination_documents':
        return _applyVaccinationDocuments(row);
      case 'pet_passport_documents':
        return _applyPetPassportDocuments(row);
    }
    throw UnimplementedError('pull apply for $table not wired yet');
  }

  Future<_ApplyOutcome> _applyPets(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.petsDao.getByUuid(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = PetsCompanion(
      uuid: Value(uuid),
      name: Value(row['name'] as String),
      species: Value(Species.values[row['species'] as int]),
      sex: Value(Sex.values[row['sex'] as int]),
      isNeutered: Value((row['isNeutered'] as bool?) ?? false),
      breed: Value(row['breed'] as String?),
      dateOfBirth: Value(_toDateTime(row['dateOfBirth'])),
      color: Value(row['color'] as String?),
      markings: Value(row['markings'] as String?),
      chipNumber: Value(row['chipNumber'] as String?),
      tassoNumber: Value(row['tassoNumber'] as String?),
      tassoRegisteredAt: Value(_toDateTime(row['tassoRegisteredAt'])),
      vaccinationPassportNumber:
          Value(row['vaccinationPassportNumber'] as String?),
      profilePhotoPath: Value(row['profilePhotoPath'] as String?),
      profilePhotoStorageKey:
          Value(row['profilePhotoStorageKey'] as String?),
      allergies: Value(row['allergies'] as String?),
      notes: Value(row['notes'] as String?),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
    );

    await _db
        .into(_db.pets)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.pets.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyVets(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.vetsDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = VetsCompanion(
      uuid: Value(uuid),
      petId: Value(row['petId'] as int),
      name: Value(row['name'] as String),
      practice: Value(row['practice'] as String?),
      address: Value(row['address'] as String?),
      phone: Value(row['phone'] as String?),
      email: Value(row['email'] as String?),
      notes: Value(row['notes'] as String?),
      isActive: Value((row['isActive'] as bool?) ?? true),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.vets)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.vets.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyContacts(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.contactsDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = ContactsCompanion(
      uuid: Value(uuid),
      petId: Value(row['petId'] as int),
      role: Value(ContactRole.values[row['role'] as int]),
      name: Value(row['name'] as String),
      organization: Value(row['organization'] as String?),
      address: Value(row['address'] as String?),
      phone: Value(row['phone'] as String?),
      email: Value(row['email'] as String?),
      notes: Value(row['notes'] as String?),
      isActive: Value((row['isActive'] as bool?) ?? true),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.contacts)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.contacts.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyFoods(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.foodsDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = FoodsCompanion(
      uuid: Value(uuid),
      petId: Value(row['petId'] as int),
      brand: Value((row['brand'] as String?) ?? ''),
      name: Value(row['name'] as String),
      foodType: Value(FoodType.values[row['foodType'] as int]),
      portionGrams: Value((row['portionGrams'] as num?)?.toDouble() ?? 0),
      frequencyPerDay: Value((row['frequencyPerDay'] as int?) ?? 1),
      timesOfDayJson: Value((row['timesOfDayJson'] as String?) ?? '[]'),
      isActive: Value((row['isActive'] as bool?) ?? true),
      startsAt: Value(_toDateTime(row['startsAt'])!),
      endsAt: Value(_toDateTime(row['endsAt'])),
      remindersEnabled: Value((row['remindersEnabled'] as bool?) ?? false),
      notes: Value(row['notes'] as String?),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.foods)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.foods.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyInsurances(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.insurancesDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = InsurancesCompanion(
      uuid: Value(uuid),
      petId: Value(row['petId'] as int),
      provider: Value(row['provider'] as String),
      policyNumber: Value(row['policyNumber'] as String?),
      contractStart: Value(_toDateTime(row['contractStart'])),
      contractEnd: Value(_toDateTime(row['contractEnd'])),
      notes: Value(row['notes'] as String?),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.insurances)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.insurances.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyEvents(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.eventsDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = EventsCompanion(
      uuid: Value(uuid),
      petId: Value(row['petId'] as int),
      eventType: Value(EventType.values[row['eventType'] as int]),
      occurredAt: Value(_toDateTime(row['occurredAt'])!),
      title: Value(row['title'] as String?),
      note: Value(row['note'] as String?),
      payloadJson: Value(row['payloadJson'] as String?),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.events)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.events.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyPetDocuments(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.petDocumentsDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    // `filePath` is a device-local hint (path on the sender's disk).
    // We keep whatever the cloud row happens to carry so a fresh
    // INSERT satisfies the NOT NULL constraint; the MediaFetcher
    // resolves via `storageKey` at read time so the nonsense-path
    // on other devices never gets opened.
    final companion = PetDocumentsCompanion(
      uuid: Value(uuid),
      petId: Value(row['petId'] as int),
      title: Value(row['title'] as String?),
      filePath: Value((row['filePath'] as String?) ?? ''),
      storageKey: Value(row['storageKey'] as String?),
      mimeType: Value(row['mimeType'] as String),
      originalFilename: Value(row['originalFilename'] as String?),
      sizeBytes: Value(row['sizeBytes'] as int?),
      notes: Value(row['notes'] as String?),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.petDocuments)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.petDocuments.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyVaccinations(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.vaccinationsDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = VaccinationsCompanion(
      uuid: Value(uuid),
      petId: Value(row['petId'] as int),
      vaccineName: Value(row['vaccineName'] as String),
      administeredAt: Value(_toDateTime(row['administeredAt'])!),
      nextDueAt: Value(_toDateTime(row['nextDueAt'])),
      vetId: Value(row['vetId'] as int?),
      batchNumber: Value(row['batchNumber'] as String?),
      notes: Value(row['notes'] as String?),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.vaccinations)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.vaccinations.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyMedications(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.medicationsDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = MedicationsCompanion(
      uuid: Value(uuid),
      petId: Value(row['petId'] as int),
      name: Value(row['name'] as String),
      dosageAmount: Value((row['dosageAmount'] as num?)?.toDouble() ?? 0),
      dosageUnit: Value((row['dosageUnit'] as String?) ?? ''),
      freqType: Value(FreqType.values[row['freqType'] as int]),
      freqInterval: Value((row['freqInterval'] as int?) ?? 1),
      freqWeekdays: Value((row['freqWeekdays'] as int?) ?? 0),
      timesOfDayJson: Value((row['timesOfDayJson'] as String?) ?? '[]'),
      startsAt: Value(_toDateTime(row['startsAt'])!),
      endsAt: Value(_toDateTime(row['endsAt'])),
      isActive: Value((row['isActive'] as bool?) ?? true),
      notes: Value(row['notes'] as String?),
      prescribedByVetId: Value(row['prescribedByVetId'] as int?),
      withFood: Value((row['withFood'] as bool?) ?? false),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.medications)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.medications.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyAppointments(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.appointmentsDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = AppointmentsCompanion(
      uuid: Value(uuid),
      petId: Value(row['petId'] as int),
      vetId: Value(row['vetId'] as int?),
      contactId: Value(row['contactId'] as int?),
      type: Value(AppointmentType.values[row['type'] as int]),
      title: Value(row['title'] as String),
      startsAt: Value(_toDateTime(row['startsAt'])!),
      durationMinutes: Value((row['durationMinutes'] as int?) ?? 60),
      location: Value(row['location'] as String?),
      notes: Value(row['notes'] as String?),
      recurrenceFreq: Value(RecurrenceFreq.values[row['recurrenceFreq'] as int]),
      recurrenceInterval: Value((row['recurrenceInterval'] as int?) ?? 1),
      recurrenceWeekdays: Value((row['recurrenceWeekdays'] as int?) ?? 0),
      recurrenceUntil: Value(_toDateTime(row['recurrenceUntil'])),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.appointments)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.appointments.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyEventPhotos(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.eventPhotosDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = EventPhotosCompanion(
      uuid: Value(uuid),
      eventId: Value(row['eventId'] as int),
      title: Value(row['title'] as String?),
      filePath: Value((row['filePath'] as String?) ?? ''),
      storageKey: Value(row['storageKey'] as String?),
      mimeType: Value(row['mimeType'] as String),
      sizeBytes: Value(row['sizeBytes'] as int?),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.eventPhotos)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.eventPhotos.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyFoodPhotos(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.foodPhotosDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = FoodPhotosCompanion(
      uuid: Value(uuid),
      foodId: Value(row['foodId'] as int),
      title: Value(row['title'] as String?),
      filePath: Value((row['filePath'] as String?) ?? ''),
      storageKey: Value(row['storageKey'] as String?),
      mimeType: Value(row['mimeType'] as String),
      originalFilename: Value(row['originalFilename'] as String?),
      sizeBytes: Value(row['sizeBytes'] as int?),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.foodPhotos)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.foodPhotos.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyInsuranceDocuments(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.insuranceDocumentsDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = InsuranceDocumentsCompanion(
      uuid: Value(uuid),
      insuranceId: Value(row['insuranceId'] as int),
      title: Value(row['title'] as String?),
      filePath: Value((row['filePath'] as String?) ?? ''),
      storageKey: Value(row['storageKey'] as String?),
      mimeType: Value(row['mimeType'] as String),
      originalFilename: Value(row['originalFilename'] as String?),
      sizeBytes: Value(row['sizeBytes'] as int?),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.insuranceDocuments)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.insuranceDocuments.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyVaccinationDocuments(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.vaccinationDocumentsDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = VaccinationDocumentsCompanion(
      uuid: Value(uuid),
      vaccinationId: Value(row['vaccinationId'] as int),
      title: Value(row['title'] as String?),
      filePath: Value((row['filePath'] as String?) ?? ''),
      storageKey: Value(row['storageKey'] as String?),
      mimeType: Value(row['mimeType'] as String),
      originalFilename: Value(row['originalFilename'] as String?),
      sizeBytes: Value(row['sizeBytes'] as int?),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.vaccinationDocuments)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.vaccinationDocuments.uuid]));
    return _ApplyOutcome.wrote;
  }

  Future<_ApplyOutcome> _applyPetPassportDocuments(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final incomingUa = row['updatedAt'] as int;
    final existing = await _db.petPassportDocumentsDao.getByUuidIncludingDeleted(uuid);
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >= incomingUa) {
      return _ApplyOutcome.lwwSkipped;
    }

    final companion = PetPassportDocumentsCompanion(
      uuid: Value(uuid),
      petId: Value(row['petId'] as int),
      title: Value(row['title'] as String?),
      filePath: Value((row['filePath'] as String?) ?? ''),
      storageKey: Value(row['storageKey'] as String?),
      mimeType: Value(row['mimeType'] as String),
      originalFilename: Value(row['originalFilename'] as String?),
      sizeBytes: Value(row['sizeBytes'] as int?),
      createdAt: Value(_toDateTime(row['createdAt'])!),
      updatedAt: Value(_toDateTime(row['updatedAt'])!),
      householdId: Value(row['householdId'] as String?),
      updatedByUserId: Value(row['updatedByUserId'] as String?),
      deletedAt: Value(_toDateTime(row['deletedAt'])),
    );

    await _db
        .into(_db.petPassportDocuments)
        .insert(companion, onConflict: DoUpdate((_) => companion, target: [_db.petPassportDocuments.uuid]));
    return _ApplyOutcome.wrote;
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    if (v is String) return DateTime.parse(v);
    return null;
  }
}

const _incomingFkMap = <String, List<_IncomingFk>>{
  'vets': [_IncomingFk('petId', 'pets', required: true)],
  'contacts': [_IncomingFk('petId', 'pets', required: true)],
  'appointments': [
    _IncomingFk('petId', 'pets', required: true),
    _IncomingFk('vetId', 'vets', required: false),
    _IncomingFk('contactId', 'contacts', required: false),
  ],
  'medications': [
    _IncomingFk('petId', 'pets', required: true),
    _IncomingFk('prescribedByVetId', 'vets', required: false),
  ],
  'foods': [_IncomingFk('petId', 'pets', required: true)],
  'vaccinations': [
    _IncomingFk('petId', 'pets', required: true),
    _IncomingFk('vetId', 'vets', required: false),
  ],
  'insurances': [_IncomingFk('petId', 'pets', required: true)],
  'events': [_IncomingFk('petId', 'pets', required: true)],
  'pet_documents': [_IncomingFk('petId', 'pets', required: true)],
  'event_photos': [_IncomingFk('eventId', 'events', required: true)],
  'food_photos': [_IncomingFk('foodId', 'foods', required: true)],
  'insurance_documents': [_IncomingFk('insuranceId', 'insurances', required: true)],
  'vaccination_documents': [_IncomingFk('vaccinationId', 'vaccinations', required: true)],
  'pet_passport_documents': [_IncomingFk('petId', 'pets', required: true)],
};

class _IncomingFk {
  const _IncomingFk(this.localKey, this.parentTable, {required this.required});
  final String localKey;
  final String parentTable;
  final bool required;
}

enum _ApplyOutcome { wrote, lwwSkipped }

/// Outcome variants exposed by [PullEngine.applyRow] — the realtime
/// engine surfaces these for its own counters.
enum RealtimeApplyOutcome { wrote, lwwSkipped, missingParent }

class PullResult {
  const PullResult({
    required this.applied,
    required this.lwwSkipped,
    required this.missingParent,
  });
  final int applied;
  final int lwwSkipped;
  final int missingParent;
}
