import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../../../core/db/database.dart';
import '../../pets/domain/pet_enums.dart';

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
  final List<String> errors;

  int get totalInserted =>
      petsInserted + vetsInserted + insurancesInserted + vaccinationsInserted;

  int get totalUpdated =>
      petsUpdated + vetsUpdated + insurancesUpdated + vaccinationsUpdated;
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

  static const int supportedSchemaVersion = 1;

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
    if (schema != supportedSchemaVersion) {
      throw ImportException(
        'Unsupported schema_version: $schema (expected $supportedSchemaVersion)',
      );
    }
    final rawPets = decoded['pets'];
    if (rawPets is! List) {
      throw ImportException('Missing "pets" array');
    }
    return _apply(rawPets.cast<dynamic>());
  }

  Future<ImportSummary> _apply(List<dynamic> rawPets) async {
    int petsInserted = 0;
    int petsUpdated = 0;
    int vetsInserted = 0;
    int vetsUpdated = 0;
    int insurancesInserted = 0;
    int insurancesUpdated = 0;
    int vaccinationsInserted = 0;
    int vaccinationsUpdated = 0;
    final errors = <String>[];

    await _db.transaction(() async {
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
      errors: errors,
    );
  }

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
}
