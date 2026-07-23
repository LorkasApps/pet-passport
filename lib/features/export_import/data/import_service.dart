import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../../../core/db/database.dart';
import '../../../core/time/time_of_day_json.dart';
import '../../appointments/domain/appointment_enums.dart';
import '../../diet/domain/food_enums.dart';
import '../../medications/domain/medication_enums.dart';
import '../../pets/domain/pet_enums.dart';
import '../../protocol/domain/event_enums.dart';

class ImportSummary {
  const ImportSummary({
    required this.petsInserted,
    required this.petsUpdated,
    required this.vetsInserted,
    required this.vetsUpdated,
    required this.insurancesInserted,
    required this.insurancesUpdated,
    required this.vaccinationsInserted,
    required this.vaccinationsUpdated,
    required this.eventsInserted,
    required this.eventsUpdated,
    required this.appointmentsInserted,
    required this.appointmentsUpdated,
    required this.medicationsInserted,
    required this.medicationsUpdated,
    required this.foodsInserted,
    required this.foodsUpdated,
    required this.tagsInserted,
    required this.errors,
  });

  final int petsInserted;
  final int petsUpdated;
  final int vetsInserted;
  final int vetsUpdated;
  final int insurancesInserted;
  final int insurancesUpdated;
  final int vaccinationsInserted;
  final int vaccinationsUpdated;
  final int eventsInserted;
  final int eventsUpdated;
  final int appointmentsInserted;
  final int appointmentsUpdated;
  final int medicationsInserted;
  final int medicationsUpdated;
  final int foodsInserted;
  final int foodsUpdated;
  final int tagsInserted;
  final List<String> errors;

  int get totalInserted =>
      petsInserted +
      vetsInserted +
      insurancesInserted +
      vaccinationsInserted +
      eventsInserted +
      appointmentsInserted +
      medicationsInserted +
      foodsInserted +
      tagsInserted;

  int get totalUpdated =>
      petsUpdated +
      vetsUpdated +
      insurancesUpdated +
      vaccinationsUpdated +
      eventsUpdated +
      appointmentsUpdated +
      medicationsUpdated +
      foodsUpdated;
}

class ImportException implements Exception {
  ImportException(this.message);
  final String message;
  @override
  String toString() => 'ImportException: $message';
}

/// UUID-based upsert import. Rebuilds cross-references (vet_uuid on
/// vaccinations) by resolving to internal ids inside a single transaction.
/// Attached-document rows are recreated on each import for their owning
/// entity — the actual files on disk are NOT re-created and must be
/// restored separately from the app storage folder.
class ImportService {
  ImportService(this._db);

  final AppDatabase _db;

  static const Set<int> supportedSchemaVersions = {1, 2, 3};

  Future<ImportSummary> importFromFile(File file) async {
    final content = await file.readAsString();
    return importFromJsonString(content);
  }

  Future<ImportSummary> importFromJsonString(String jsonString) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (_) {
      throw ImportException('File is not valid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ImportException('Root element must be an object');
    }
    final schema = decoded['schema_version'];
    if (schema is! int || !supportedSchemaVersions.contains(schema)) {
      throw ImportException(
        'Unsupported schema_version: $schema (expected one of $supportedSchemaVersions)',
      );
    }
    final rawPets = decoded['pets'];
    if (rawPets is! List) {
      throw ImportException('Missing "pets" array');
    }
    final rawTags = decoded['tags'];
    return _apply(
      rawPets.cast<dynamic>(),
      rawTags is List ? rawTags.cast<dynamic>() : const [],
    );
  }

  Future<ImportSummary> _apply(
    List<dynamic> rawPets,
    List<dynamic> rawTags,
  ) async {
    int petsInserted = 0;
    int petsUpdated = 0;
    int vetsInserted = 0;
    int vetsUpdated = 0;
    int insurancesInserted = 0;
    int insurancesUpdated = 0;
    int vaccinationsInserted = 0;
    int vaccinationsUpdated = 0;
    int eventsInserted = 0;
    int eventsUpdated = 0;
    int appointmentsInserted = 0;
    int appointmentsUpdated = 0;
    int medicationsInserted = 0;
    int medicationsUpdated = 0;
    int foodsInserted = 0;
    int foodsUpdated = 0;
    int tagsInserted = 0;
    final errors = <String>[];

    await _db.transaction(() async {
      final tagIdByUuid = <String, int>{};
      for (final rt in rawTags) {
        if (rt is! Map<String, dynamic>) continue;
        try {
          final id =
              await _upsertTag(rt, () => tagsInserted++);
          if (id != null) tagIdByUuid[rt['uuid'] as String] = id;
        } catch (e) {
          errors.add('Tag ${rt['uuid']}: $e');
        }
      }
      for (final rawPet in rawPets) {
        if (rawPet is! Map<String, dynamic>) {
          errors.add('Skipped a pet entry: not an object');
          continue;
        }
        try {
          final petId = await _upsertPet(rawPet, () => petsInserted++,
              () => petsUpdated++);

          final rawWeights = rawPet['weights'];
          if (rawWeights is List) {
            await (_db.delete(_db.petWeights)
                  ..where((w) => w.petId.equals(petId)))
                .go();
            for (final rw in rawWeights) {
              if (rw is! Map<String, dynamic>) continue;
              final measured = _parseDt(rw['measured_at']);
              final weightKg = (rw['weight_kg'] as num?)?.toDouble();
              if (measured == null || weightKg == null) continue;
              await _db.into(_db.petWeights).insert(PetWeightsCompanion.insert(
                    petId: petId,
                    measuredAt: measured,
                    weightKg: weightKg,
                    note: Value(rw['note'] as String?),
                  ));
            }
          }

          final vetIdByUuid = <String, int>{};
          final rawVets = rawPet['vets'];
          if (rawVets is List) {
            for (final rv in rawVets) {
              if (rv is! Map<String, dynamic>) continue;
              try {
                final vetId = await _upsertVet(petId, rv,
                    () => vetsInserted++, () => vetsUpdated++);
                vetIdByUuid[rv['uuid'] as String] = vetId;
              } catch (e) {
                errors.add('Vet ${rv['uuid']}: $e');
              }
            }
          }

          final rawInsurances = rawPet['insurances'];
          if (rawInsurances is List) {
            for (final ri in rawInsurances) {
              if (ri is! Map<String, dynamic>) continue;
              try {
                await _upsertInsurance(petId, ri,
                    () => insurancesInserted++, () => insurancesUpdated++);
              } catch (e) {
                errors.add('Insurance ${ri['uuid']}: $e');
              }
            }
          }

          final rawVaccinations = rawPet['vaccinations'];
          if (rawVaccinations is List) {
            for (final rv in rawVaccinations) {
              if (rv is! Map<String, dynamic>) continue;
              try {
                await _upsertVaccination(petId, rv, vetIdByUuid,
                    () => vaccinationsInserted++,
                    () => vaccinationsUpdated++);
              } catch (e) {
                errors.add('Vaccination ${rv['uuid']}: $e');
              }
            }
          }

          final rawEvents = rawPet['events'];
          if (rawEvents is List) {
            for (final re in rawEvents) {
              if (re is! Map<String, dynamic>) continue;
              try {
                await _upsertEvent(petId, re, tagIdByUuid,
                    () => eventsInserted++, () => eventsUpdated++);
              } catch (e) {
                errors.add('Event ${re['uuid']}: $e');
              }
            }
          }

          final rawAppointments = rawPet['appointments'];
          if (rawAppointments is List) {
            for (final ra in rawAppointments) {
              if (ra is! Map<String, dynamic>) continue;
              try {
                await _upsertAppointment(petId, ra, vetIdByUuid,
                    () => appointmentsInserted++,
                    () => appointmentsUpdated++);
              } catch (e) {
                errors.add('Appointment ${ra['uuid']}: $e');
              }
            }
          }

          final rawMedications = rawPet['medications'];
          if (rawMedications is List) {
            for (final rm in rawMedications) {
              if (rm is! Map<String, dynamic>) continue;
              try {
                await _upsertMedication(petId, rm, vetIdByUuid,
                    () => medicationsInserted++,
                    () => medicationsUpdated++);
              } catch (e) {
                errors.add('Medication ${rm['uuid']}: $e');
              }
            }
          }

          final rawFoods = rawPet['foods'];
          if (rawFoods is List) {
            for (final rf in rawFoods) {
              if (rf is! Map<String, dynamic>) continue;
              try {
                await _upsertFood(petId, rf,
                    () => foodsInserted++, () => foodsUpdated++);
              } catch (e) {
                errors.add('Food ${rf['uuid']}: $e');
              }
            }
          }
        } catch (e) {
          errors.add('Pet ${rawPet['uuid']}: $e');
        }
      }
    });

    return ImportSummary(
      petsInserted: petsInserted,
      petsUpdated: petsUpdated,
      vetsInserted: vetsInserted,
      vetsUpdated: vetsUpdated,
      insurancesInserted: insurancesInserted,
      insurancesUpdated: insurancesUpdated,
      vaccinationsInserted: vaccinationsInserted,
      vaccinationsUpdated: vaccinationsUpdated,
      eventsInserted: eventsInserted,
      eventsUpdated: eventsUpdated,
      appointmentsInserted: appointmentsInserted,
      appointmentsUpdated: appointmentsUpdated,
      medicationsInserted: medicationsInserted,
      medicationsUpdated: medicationsUpdated,
      foodsInserted: foodsInserted,
      foodsUpdated: foodsUpdated,
      tagsInserted: tagsInserted,
      errors: errors,
    );
  }

  Future<int?> _upsertTag(
    Map<String, dynamic> raw,
    void Function() onInsert,
  ) async {
    final uuid = raw['uuid'] as String?;
    final label = (raw['label'] as String?)?.trim();
    if (uuid == null || uuid.isEmpty || label == null || label.isEmpty) {
      throw ImportException('Missing uuid or label');
    }
    final existing = await (_db.select(_db.eventTags)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    final now = DateTime.now();
    final id = await _db.into(_db.eventTags).insert(EventTagsCompanion.insert(
          uuid: uuid,
          label: label,
          color: Value((raw['color'] as num?)?.toInt()),
          createdAt: _parseDt(raw['created_at']) ?? now,
        ));
    onInsert();
    return id;
  }

  Future<void> _upsertEvent(
    int petId,
    Map<String, dynamic> raw,
    Map<String, int> tagIdByUuid,
    void Function() onInsert,
    void Function() onUpdate,
  ) async {
    final uuid = raw['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) throw ImportException('Missing uuid');
    final type = _parseEventType(raw['event_type']);
    final occurred = _parseDt(raw['occurred_at']);
    if (occurred == null) throw ImportException('Missing occurred_at');
    final payloadRaw = raw['payload'];
    final payloadJson = payloadRaw is Map<String, dynamic> && payloadRaw.isNotEmpty
        ? jsonEncode(payloadRaw)
        : null;
    final existing = await (_db.select(_db.events)
          ..where((e) => e.uuid.equals(uuid)))
        .getSingleOrNull();
    final now = DateTime.now();
    final int eventId;
    if (existing == null) {
      eventId = await _db.into(_db.events).insert(EventsCompanion.insert(
            uuid: uuid,
            petId: petId,
            eventType: type,
            occurredAt: occurred,
            title: Value(raw['title'] as String?),
            note: Value(raw['note'] as String?),
            payloadJson: Value(payloadJson),
            createdAt: _parseDt(raw['created_at']) ?? now,
            updatedAt: now,
          ));
      onInsert();
    } else {
      await (_db.update(_db.events)..where((e) => e.uuid.equals(uuid)))
          .write(EventsCompanion(
        petId: Value(petId),
        eventType: Value(type),
        occurredAt: Value(occurred),
        title: Value(raw['title'] as String?),
        note: Value(raw['note'] as String?),
        payloadJson: Value(payloadJson),
        updatedAt: Value(now),
      ));
      eventId = existing.id;
      onUpdate();
    }

    // Reset tag links from scratch — cheaper than diffing.
    await (_db.delete(_db.eventTagLinks)
          ..where((l) => l.eventId.equals(eventId)))
        .go();
    final tagUuids = raw['tag_uuids'];
    if (tagUuids is List) {
      for (final tu in tagUuids) {
        if (tu is! String) continue;
        final tagId = tagIdByUuid[tu];
        if (tagId == null) continue;
        await _db.into(_db.eventTagLinks).insertOnConflictUpdate(
              EventTagLinksCompanion.insert(eventId: eventId, tagId: tagId),
            );
      }
    }

    // Rebuild photo rows for this event.
    await (_db.delete(_db.eventPhotos)
          ..where((p) => p.eventId.equals(eventId)))
        .go();
    final photos = raw['photos'];
    if (photos is List) {
      for (final rp in photos) {
        if (rp is! Map<String, dynamic>) continue;
        final photoUuid = rp['uuid'] as String?;
        final filePath = rp['file_path'] as String?;
        final mimeType = rp['mime_type'] as String?;
        if (photoUuid == null || filePath == null || mimeType == null) continue;
        await _db.into(_db.eventPhotos).insert(EventPhotosCompanion.insert(
              uuid: photoUuid,
              eventId: eventId,
              filePath: filePath,
              mimeType: mimeType,
              sizeBytes: Value((rp['size_bytes'] as num?)?.toInt()),
              createdAt: _parseDt(rp['created_at']) ?? now,
            ));
      }
    }
  }

  EventType _parseEventType(dynamic v) => switch (v) {
        'weight' => EventType.weight,
        'feeding' => EventType.feeding,
        'symptom' => EventType.symptom,
        'activity' => EventType.activity,
        'generic' => EventType.generic,
        _ => throw ImportException('Unknown event_type: $v'),
      };

  Future<int> _upsertPet(
    Map<String, dynamic> raw,
    void Function() onInsert,
    void Function() onUpdate,
  ) async {
    final uuid = raw['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) {
      throw ImportException('Missing uuid');
    }
    final name = raw['name'] as String?;
    if (name == null || name.isEmpty) {
      throw ImportException('Missing name');
    }
    final species = _parseSpecies(raw['species']);
    final sex = _parseSex(raw['sex']);
    final existing = await (_db.select(_db.pets)
          ..where((p) => p.uuid.equals(uuid)))
        .getSingleOrNull();
    final now = DateTime.now();
    if (existing == null) {
      final id = await _db.into(_db.pets).insert(PetsCompanion.insert(
            uuid: uuid,
            name: name,
            species: species,
            sex: sex,
            isNeutered: Value(raw['is_neutered'] as bool? ?? false),
            breed: Value(raw['breed'] as String?),
            dateOfBirth: Value(_parseDt(raw['date_of_birth'])),
            color: Value(raw['color'] as String?),
            markings: Value(raw['markings'] as String?),
            chipNumber: Value(raw['chip_number'] as String?),
            tassoNumber: Value(raw['tasso_number'] as String?),
            tassoRegisteredAt: Value(_parseDt(raw['tasso_registered_at'])),
            vaccinationPassportNumber:
                Value(raw['vaccination_passport_number'] as String?),
            profilePhotoPath: Value(raw['profile_photo_path'] as String?),
            allergies: Value(raw['allergies'] as String?),
            notes: Value(raw['notes'] as String?),
            createdAt: _parseDt(raw['created_at']) ?? now,
            updatedAt: now,
          ));
      onInsert();
      return id;
    }
    await (_db.update(_db.pets)..where((p) => p.uuid.equals(uuid)))
        .write(PetsCompanion(
      name: Value(name),
      species: Value(species),
      sex: Value(sex),
      isNeutered: Value(raw['is_neutered'] as bool? ?? existing.isNeutered),
      breed: Value(raw['breed'] as String?),
      dateOfBirth: Value(_parseDt(raw['date_of_birth'])),
      color: Value(raw['color'] as String?),
      markings: Value(raw['markings'] as String?),
      chipNumber: Value(raw['chip_number'] as String?),
      tassoNumber: Value(raw['tasso_number'] as String?),
      tassoRegisteredAt: Value(_parseDt(raw['tasso_registered_at'])),
      vaccinationPassportNumber:
          Value(raw['vaccination_passport_number'] as String?),
      profilePhotoPath: Value(raw['profile_photo_path'] as String?),
      allergies: Value(raw['allergies'] as String?),
      notes: Value(raw['notes'] as String?),
      updatedAt: Value(now),
      deletedAt: const Value(null),
    ));
    onUpdate();
    return existing.id;
  }

  Future<int> _upsertVet(
    int petId,
    Map<String, dynamic> raw,
    void Function() onInsert,
    void Function() onUpdate,
  ) async {
    final uuid = raw['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) throw ImportException('Missing uuid');
    final name = raw['name'] as String?;
    if (name == null || name.isEmpty) throw ImportException('Missing name');
    final existing = await (_db.select(_db.vets)
          ..where((v) => v.uuid.equals(uuid)))
        .getSingleOrNull();
    final now = DateTime.now();
    if (existing == null) {
      final id = await _db.into(_db.vets).insert(VetsCompanion.insert(
            uuid: uuid,
            petId: petId,
            name: name,
            practice: Value(raw['practice'] as String?),
            address: Value(raw['address'] as String?),
            phone: Value(raw['phone'] as String?),
            email: Value(raw['email'] as String?),
            notes: Value(raw['notes'] as String?),
            isActive: Value((raw['is_active'] as bool?) ?? true),
            createdAt: _parseDt(raw['created_at']) ?? now,
            updatedAt: now,
          ));
      onInsert();
      return id;
    }
    await (_db.update(_db.vets)..where((v) => v.uuid.equals(uuid)))
        .write(VetsCompanion(
      petId: Value(petId),
      name: Value(name),
      practice: Value(raw['practice'] as String?),
      address: Value(raw['address'] as String?),
      phone: Value(raw['phone'] as String?),
      email: Value(raw['email'] as String?),
      notes: Value(raw['notes'] as String?),
      isActive: Value((raw['is_active'] as bool?) ?? true),
      updatedAt: Value(now),
    ));
    onUpdate();
    return existing.id;
  }

  Future<int> _upsertInsurance(
    int petId,
    Map<String, dynamic> raw,
    void Function() onInsert,
    void Function() onUpdate,
  ) async {
    final uuid = raw['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) throw ImportException('Missing uuid');
    final provider = raw['provider'] as String?;
    if (provider == null || provider.isEmpty) {
      throw ImportException('Missing provider');
    }
    final existing = await (_db.select(_db.insurances)
          ..where((i) => i.uuid.equals(uuid)))
        .getSingleOrNull();
    final now = DateTime.now();
    final int insuranceId;
    if (existing == null) {
      insuranceId =
          await _db.into(_db.insurances).insert(InsurancesCompanion.insert(
                uuid: uuid,
                petId: petId,
                provider: provider,
                policyNumber: Value(raw['policy_number'] as String?),
                contractStart: Value(_parseDt(raw['contract_start'])),
                contractEnd: Value(_parseDt(raw['contract_end'])),
                notes: Value(raw['notes'] as String?),
                createdAt: _parseDt(raw['created_at']) ?? now,
                updatedAt: now,
              ));
      onInsert();
    } else {
      await (_db.update(_db.insurances)..where((i) => i.uuid.equals(uuid)))
          .write(InsurancesCompanion(
        petId: Value(petId),
        provider: Value(provider),
        policyNumber: Value(raw['policy_number'] as String?),
        contractStart: Value(_parseDt(raw['contract_start'])),
        contractEnd: Value(_parseDt(raw['contract_end'])),
        notes: Value(raw['notes'] as String?),
        updatedAt: Value(now),
      ));
      insuranceId = existing.id;
      onUpdate();
    }
    await _reinsertInsuranceDocs(insuranceId, raw['documents']);
    return insuranceId;
  }

  Future<int> _upsertVaccination(
    int petId,
    Map<String, dynamic> raw,
    Map<String, int> vetIdByUuid,
    void Function() onInsert,
    void Function() onUpdate,
  ) async {
    final uuid = raw['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) throw ImportException('Missing uuid');
    final vaccineName = raw['vaccine_name'] as String?;
    if (vaccineName == null || vaccineName.isEmpty) {
      throw ImportException('Missing vaccine_name');
    }
    final administered = _parseDt(raw['administered_at']);
    if (administered == null) {
      throw ImportException('Missing administered_at');
    }
    final vetUuid = raw['vet_uuid'] as String?;
    int? vetId = vetUuid == null ? null : vetIdByUuid[vetUuid];
    if (vetId == null && vetUuid != null) {
      final vetRow = await (_db.select(_db.vets)
            ..where((v) => v.uuid.equals(vetUuid)))
          .getSingleOrNull();
      vetId = vetRow?.id;
    }
    final existing = await (_db.select(_db.vaccinations)
          ..where((v) => v.uuid.equals(uuid)))
        .getSingleOrNull();
    final now = DateTime.now();
    final int vacId;
    if (existing == null) {
      vacId =
          await _db.into(_db.vaccinations).insert(VaccinationsCompanion.insert(
                uuid: uuid,
                petId: petId,
                vaccineName: vaccineName,
                administeredAt: administered,
                nextDueAt: Value(_parseDt(raw['next_due_at'])),
                vetId: Value(vetId),
                batchNumber: Value(raw['batch_number'] as String?),
                notes: Value(raw['notes'] as String?),
                createdAt: _parseDt(raw['created_at']) ?? now,
                updatedAt: now,
              ));
      onInsert();
    } else {
      await (_db.update(_db.vaccinations)..where((v) => v.uuid.equals(uuid)))
          .write(VaccinationsCompanion(
        petId: Value(petId),
        vaccineName: Value(vaccineName),
        administeredAt: Value(administered),
        nextDueAt: Value(_parseDt(raw['next_due_at'])),
        vetId: Value(vetId),
        batchNumber: Value(raw['batch_number'] as String?),
        notes: Value(raw['notes'] as String?),
        updatedAt: Value(now),
      ));
      vacId = existing.id;
      onUpdate();
    }
    await _reinsertVaccinationDocs(vacId, raw['documents']);
    return vacId;
  }

  Future<void> _reinsertInsuranceDocs(int insuranceId, dynamic rawDocs) async {
    await (_db.delete(_db.insuranceDocuments)
          ..where((d) => d.insuranceId.equals(insuranceId)))
        .go();
    if (rawDocs is! List) return;
    for (final rd in rawDocs) {
      if (rd is! Map<String, dynamic>) continue;
      final uuid = rd['uuid'] as String?;
      final filePath = rd['file_path'] as String?;
      final mimeType = rd['mime_type'] as String?;
      if (uuid == null || filePath == null || mimeType == null) continue;
      await _db
          .into(_db.insuranceDocuments)
          .insert(InsuranceDocumentsCompanion.insert(
            uuid: uuid,
            insuranceId: insuranceId,
            filePath: filePath,
            mimeType: mimeType,
            originalFilename: Value(rd['original_filename'] as String?),
            sizeBytes: Value((rd['size_bytes'] as num?)?.toInt()),
            createdAt: _parseDt(rd['created_at']) ?? DateTime.now(),
          ));
    }
  }

  Future<void> _reinsertVaccinationDocs(int vacId, dynamic rawDocs) async {
    await (_db.delete(_db.vaccinationDocuments)
          ..where((d) => d.vaccinationId.equals(vacId)))
        .go();
    if (rawDocs is! List) return;
    for (final rd in rawDocs) {
      if (rd is! Map<String, dynamic>) continue;
      final uuid = rd['uuid'] as String?;
      final filePath = rd['file_path'] as String?;
      final mimeType = rd['mime_type'] as String?;
      if (uuid == null || filePath == null || mimeType == null) continue;
      await _db
          .into(_db.vaccinationDocuments)
          .insert(VaccinationDocumentsCompanion.insert(
            uuid: uuid,
            vaccinationId: vacId,
            filePath: filePath,
            mimeType: mimeType,
            originalFilename: Value(rd['original_filename'] as String?),
            sizeBytes: Value((rd['size_bytes'] as num?)?.toInt()),
            createdAt: _parseDt(rd['created_at']) ?? DateTime.now(),
          ));
    }
  }

  DateTime? _parseDt(dynamic v) {
    if (v is! String) return null;
    return DateTime.tryParse(v);
  }

  Species _parseSpecies(dynamic v) => switch (v) {
        'dog' => Species.dog,
        'cat' => Species.cat,
        _ => throw ImportException('Unknown species: $v'),
      };

  Sex _parseSex(dynamic v) => switch (v) {
        'male' => Sex.male,
        'female' => Sex.female,
        _ => throw ImportException('Unknown sex: $v'),
      };

  AppointmentType _parseAppointmentType(dynamic v) => switch (v) {
        'vet' => AppointmentType.vet,
        'grooming' => AppointmentType.grooming,
        'training' => AppointmentType.training,
        'walk' => AppointmentType.walk,
        'checkup' => AppointmentType.checkup,
        'other' => AppointmentType.other,
        _ => throw ImportException('Unknown appointment type: $v'),
      };

  RecurrenceFreq _parseRecurrenceFreq(dynamic v) => switch (v) {
        null => RecurrenceFreq.none,
        'none' => RecurrenceFreq.none,
        'daily' => RecurrenceFreq.daily,
        'weekly' => RecurrenceFreq.weekly,
        'monthly' => RecurrenceFreq.monthly,
        _ => throw ImportException('Unknown recurrence_freq: $v'),
      };

  FreqType _parseFreqType(dynamic v) => switch (v) {
        'daily' => FreqType.daily,
        'weekly' => FreqType.weekly,
        'intervalDays' => FreqType.intervalDays,
        _ => throw ImportException('Unknown freq_type: $v'),
      };

  FoodType _parseFoodType(dynamic v) => switch (v) {
        'dry' => FoodType.dry,
        'wet' => FoodType.wet,
        'raw' => FoodType.raw,
        'barf' => FoodType.barf,
        'treat' => FoodType.treat,
        'other' => FoodType.other,
        _ => throw ImportException('Unknown food_type: $v'),
      };

  List<int> _parseOffsets(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => (e as num?)?.toInt())
        .whereType<int>()
        .toList(growable: false);
  }

  List<String> _parseTimesOfDay(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().toList(growable: false);
  }

  Future<int> _upsertAppointment(
    int petId,
    Map<String, dynamic> raw,
    Map<String, int> vetIdByUuid,
    void Function() onInsert,
    void Function() onUpdate,
  ) async {
    final uuid = raw['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) throw ImportException('Missing uuid');
    final title = raw['title'] as String?;
    if (title == null || title.isEmpty) {
      throw ImportException('Missing title');
    }
    final startsAt = _parseDt(raw['starts_at']);
    if (startsAt == null) throw ImportException('Missing starts_at');
    final type = _parseAppointmentType(raw['type']);
    final vetUuid = raw['vet_uuid'] as String?;
    int? vetId = vetUuid == null ? null : vetIdByUuid[vetUuid];
    if (vetId == null && vetUuid != null) {
      final row = await (_db.select(_db.vets)
            ..where((v) => v.uuid.equals(vetUuid)))
          .getSingleOrNull();
      vetId = row?.id;
    }
    final recurrenceFreq = _parseRecurrenceFreq(raw['recurrence_freq']);
    final existing = await (_db.select(_db.appointments)
          ..where((a) => a.uuid.equals(uuid)))
        .getSingleOrNull();
    final now = DateTime.now();
    final int apptId;
    if (existing == null) {
      apptId = await _db.into(_db.appointments).insert(
            AppointmentsCompanion.insert(
              uuid: uuid,
              petId: petId,
              vetId: Value(vetId),
              type: type,
              title: title,
              startsAt: startsAt,
              durationMinutes:
                  Value((raw['duration_minutes'] as num?)?.toInt() ?? 60),
              location: Value(raw['location'] as String?),
              notes: Value(raw['notes'] as String?),
              recurrenceFreq: Value(recurrenceFreq),
              recurrenceInterval:
                  Value((raw['recurrence_interval'] as num?)?.toInt() ?? 1),
              recurrenceWeekdays:
                  Value((raw['recurrence_weekdays'] as num?)?.toInt() ?? 0),
              recurrenceUntil: Value(_parseDt(raw['recurrence_until'])),
              createdAt: _parseDt(raw['created_at']) ?? now,
              updatedAt: now,
            ),
          );
      onInsert();
    } else {
      await (_db.update(_db.appointments)
            ..where((a) => a.uuid.equals(uuid)))
          .write(AppointmentsCompanion(
        petId: Value(petId),
        vetId: Value(vetId),
        type: Value(type),
        title: Value(title),
        startsAt: Value(startsAt),
        durationMinutes:
            Value((raw['duration_minutes'] as num?)?.toInt() ?? 60),
        location: Value(raw['location'] as String?),
        notes: Value(raw['notes'] as String?),
        recurrenceFreq: Value(recurrenceFreq),
        recurrenceInterval:
            Value((raw['recurrence_interval'] as num?)?.toInt() ?? 1),
        recurrenceWeekdays:
            Value((raw['recurrence_weekdays'] as num?)?.toInt() ?? 0),
        recurrenceUntil: Value(_parseDt(raw['recurrence_until'])),
        updatedAt: Value(now),
      ));
      apptId = existing.id;
      onUpdate();
    }
    // Rebuild reminders + exceptions.
    await (_db.delete(_db.appointmentReminders)
          ..where((r) => r.appointmentId.equals(apptId)))
        .go();
    for (final off in _parseOffsets(raw['reminder_offsets_minutes'])) {
      await _db.into(_db.appointmentReminders).insert(
            AppointmentRemindersCompanion.insert(
              appointmentId: apptId,
              offsetMinutes: off,
            ),
          );
    }
    await (_db.delete(_db.appointmentExceptions)
          ..where((e) => e.appointmentId.equals(apptId)))
        .go();
    final rawExceptions = raw['exceptions'];
    if (rawExceptions is List) {
      for (final rx in rawExceptions) {
        if (rx is! Map<String, dynamic>) continue;
        final occ = _parseDt(rx['occurrence_start']);
        if (occ == null) continue;
        await _db.into(_db.appointmentExceptions).insert(
              AppointmentExceptionsCompanion.insert(
                appointmentId: apptId,
                occurrenceStart: occ,
                isCancelled: Value(rx['is_cancelled'] as bool? ?? false),
                overrideStartsAt: Value(_parseDt(rx['override_starts_at'])),
              ),
            );
      }
    }
    return apptId;
  }

  Future<int> _upsertMedication(
    int petId,
    Map<String, dynamic> raw,
    Map<String, int> vetIdByUuid,
    void Function() onInsert,
    void Function() onUpdate,
  ) async {
    final uuid = raw['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) throw ImportException('Missing uuid');
    final name = raw['name'] as String?;
    if (name == null || name.isEmpty) throw ImportException('Missing name');
    final startsAt = _parseDt(raw['starts_at']);
    if (startsAt == null) throw ImportException('Missing starts_at');
    final freqType = _parseFreqType(raw['freq_type']);
    final vetUuid = raw['prescribed_by_vet_uuid'] as String?;
    int? vetId = vetUuid == null ? null : vetIdByUuid[vetUuid];
    if (vetId == null && vetUuid != null) {
      final row = await (_db.select(_db.vets)
            ..where((v) => v.uuid.equals(vetUuid)))
          .getSingleOrNull();
      vetId = row?.id;
    }
    final timesJson = TimeOfDayJson.encode(_parseTimesOfDay(raw['times_of_day']));
    final existing = await (_db.select(_db.medications)
          ..where((m) => m.uuid.equals(uuid)))
        .getSingleOrNull();
    final now = DateTime.now();
    final int medId;
    if (existing == null) {
      medId =
          await _db.into(_db.medications).insert(MedicationsCompanion.insert(
                uuid: uuid,
                petId: petId,
                name: name,
                dosageAmount:
                    Value((raw['dosage_amount'] as num?)?.toDouble() ?? 0),
                dosageUnit: Value((raw['dosage_unit'] as String?) ?? ''),
                freqType: Value(freqType),
                freqInterval:
                    Value((raw['freq_interval'] as num?)?.toInt() ?? 1),
                freqWeekdays:
                    Value((raw['freq_weekdays'] as num?)?.toInt() ?? 0),
                timesOfDayJson: Value(timesJson),
                startsAt: startsAt,
                endsAt: Value(_parseDt(raw['ends_at'])),
                isActive: Value(raw['is_active'] as bool? ?? true),
                notes: Value(raw['notes'] as String?),
                prescribedByVetId: Value(vetId),
                withFood: Value(raw['with_food'] as bool? ?? false),
                createdAt: _parseDt(raw['created_at']) ?? now,
                updatedAt: now,
              ));
      onInsert();
    } else {
      await (_db.update(_db.medications)..where((m) => m.uuid.equals(uuid)))
          .write(MedicationsCompanion(
        petId: Value(petId),
        name: Value(name),
        dosageAmount:
            Value((raw['dosage_amount'] as num?)?.toDouble() ?? 0),
        dosageUnit: Value((raw['dosage_unit'] as String?) ?? ''),
        freqType: Value(freqType),
        freqInterval: Value((raw['freq_interval'] as num?)?.toInt() ?? 1),
        freqWeekdays: Value((raw['freq_weekdays'] as num?)?.toInt() ?? 0),
        timesOfDayJson: Value(timesJson),
        startsAt: Value(startsAt),
        endsAt: Value(_parseDt(raw['ends_at'])),
        isActive: Value(raw['is_active'] as bool? ?? true),
        notes: Value(raw['notes'] as String?),
        prescribedByVetId: Value(vetId),
        withFood: Value(raw['with_food'] as bool? ?? false),
        updatedAt: Value(now),
      ));
      medId = existing.id;
      onUpdate();
    }
    // Rebuild reminders + intakes.
    await (_db.delete(_db.medicationReminders)
          ..where((r) => r.medicationId.equals(medId)))
        .go();
    for (final off in _parseOffsets(raw['reminder_offsets_minutes'])) {
      await _db.into(_db.medicationReminders).insert(
            MedicationRemindersCompanion.insert(
              medicationId: medId,
              offsetMinutes: off,
            ),
          );
    }
    await (_db.delete(_db.medicationIntakes)
          ..where((i) => i.medicationId.equals(medId)))
        .go();
    final rawIntakes = raw['intakes'];
    if (rawIntakes is List) {
      for (final ri in rawIntakes) {
        if (ri is! Map<String, dynamic>) continue;
        final intakeUuid = ri['uuid'] as String?;
        final takenAt = _parseDt(ri['taken_at']);
        if (intakeUuid == null || intakeUuid.isEmpty || takenAt == null) {
          continue;
        }
        await _db.into(_db.medicationIntakes).insert(
              MedicationIntakesCompanion.insert(
                uuid: intakeUuid,
                medicationId: medId,
                takenAt: takenAt,
                skipped: Value(ri['skipped'] as bool? ?? false),
                note: Value(ri['note'] as String?),
              ),
            );
      }
    }
    return medId;
  }

  Future<int> _upsertFood(
    int petId,
    Map<String, dynamic> raw,
    void Function() onInsert,
    void Function() onUpdate,
  ) async {
    final uuid = raw['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) throw ImportException('Missing uuid');
    final name = raw['name'] as String?;
    if (name == null || name.isEmpty) throw ImportException('Missing name');
    final startsAt = _parseDt(raw['starts_at']);
    if (startsAt == null) throw ImportException('Missing starts_at');
    final foodType = _parseFoodType(raw['food_type']);
    final timesJson = TimeOfDayJson.encode(_parseTimesOfDay(raw['times_of_day']));
    final existing = await (_db.select(_db.foods)
          ..where((f) => f.uuid.equals(uuid)))
        .getSingleOrNull();
    final now = DateTime.now();
    final int foodId;
    if (existing == null) {
      foodId = await _db.into(_db.foods).insert(FoodsCompanion.insert(
            uuid: uuid,
            petId: petId,
            brand: Value((raw['brand'] as String?) ?? ''),
            name: name,
            foodType: Value(foodType),
            portionGrams:
                Value((raw['portion_grams'] as num?)?.toDouble() ?? 0),
            frequencyPerDay:
                Value((raw['frequency_per_day'] as num?)?.toInt() ?? 1),
            timesOfDayJson: Value(timesJson),
            isActive: Value(raw['is_active'] as bool? ?? true),
            startsAt: startsAt,
            endsAt: Value(_parseDt(raw['ends_at'])),
            remindersEnabled:
                Value(raw['reminders_enabled'] as bool? ?? false),
            notes: Value(raw['notes'] as String?),
            createdAt: _parseDt(raw['created_at']) ?? now,
            updatedAt: now,
          ));
      onInsert();
    } else {
      await (_db.update(_db.foods)..where((f) => f.uuid.equals(uuid)))
          .write(FoodsCompanion(
        petId: Value(petId),
        brand: Value((raw['brand'] as String?) ?? ''),
        name: Value(name),
        foodType: Value(foodType),
        portionGrams:
            Value((raw['portion_grams'] as num?)?.toDouble() ?? 0),
        frequencyPerDay:
            Value((raw['frequency_per_day'] as num?)?.toInt() ?? 1),
        timesOfDayJson: Value(timesJson),
        isActive: Value(raw['is_active'] as bool? ?? true),
        startsAt: Value(startsAt),
        endsAt: Value(_parseDt(raw['ends_at'])),
        remindersEnabled: Value(raw['reminders_enabled'] as bool? ?? false),
        notes: Value(raw['notes'] as String?),
        updatedAt: Value(now),
      ));
      foodId = existing.id;
      onUpdate();
    }
    // Rebuild photo rows for this food (same wholesale strategy as
    // vaccination / insurance documents).
    await (_db.delete(_db.foodPhotos)
          ..where((p) => p.foodId.equals(foodId)))
        .go();
    final rawPhotos = raw['photos'];
    if (rawPhotos is List) {
      for (final rp in rawPhotos) {
        if (rp is! Map<String, dynamic>) continue;
        final photoUuid = rp['uuid'] as String?;
        final filePath = rp['file_path'] as String?;
        final mimeType = rp['mime_type'] as String?;
        if (photoUuid == null || filePath == null || mimeType == null) {
          continue;
        }
        await _db.into(_db.foodPhotos).insert(FoodPhotosCompanion.insert(
              uuid: photoUuid,
              foodId: foodId,
              filePath: filePath,
              mimeType: mimeType,
              originalFilename: Value(rp['original_filename'] as String?),
              sizeBytes: Value((rp['size_bytes'] as num?)?.toInt()),
              createdAt: _parseDt(rp['created_at']) ?? now,
            ));
      }
    }
    return foodId;
  }
}
