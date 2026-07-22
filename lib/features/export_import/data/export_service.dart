import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../insurances/data/insurances_repository.dart';
import '../../insurances/domain/insurance.dart';
import '../../pets/data/pets_repository.dart';
import '../../pets/domain/pet.dart';
import '../../pets/domain/pet_enums.dart';
import '../../protocol/data/events_repository.dart';
import '../../protocol/domain/event.dart';
import '../../protocol/domain/event_enums.dart';
import '../../vaccinations/data/vaccinations_repository.dart';
import '../../vaccinations/domain/vaccination.dart';
import '../../vets/data/vets_repository.dart';
import '../../vets/domain/vet.dart';

class ExportService {
  ExportService(
    this._pets,
    this._vets,
    this._insurances,
    this._vaccinations,
    this._events,
  );

  final PetsRepository _pets;
  final VetsRepository _vets;
  final InsurancesRepository _insurances;
  final VaccinationsRepository _vaccinations;
  final EventsRepository _events;

  static const int schemaVersion = 2;
  static const String appVersion = '0.1.0+1';

  /// Builds a plain-JSON snapshot of every active pet. Media files are
  /// referenced by their relative path — this export is intentionally
  /// text-only, so no base64 payloads. Users who need the files should
  /// copy the app documents folder alongside.
  Future<Map<String, dynamic>> buildSnapshot() async {
    final pets = await _pets.watchActivePets().first;
    final result = <Map<String, dynamic>>[];
    for (final pet in pets) {
      final vets = await _vets.watchForPetUuid(pet.uuid).first;
      final insurances = await _insurances.watchForPetUuid(pet.uuid).first;
      final vaccinations =
          await _vaccinations.watchForPetUuid(pet.uuid).first;
      final events = await _events.watchForPetUuid(pet.uuid).first;
      result.add(_petToJson(pet, vets, insurances, vaccinations, events));
    }
    final tags = await _events.watchAllTags().first;
    return {
      'schema_version': schemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'app_version': appVersion,
      'tags': [
        for (final t in tags)
          {
            'uuid': t.uuid,
            'label': t.label,
            'color': t.color,
            'created_at': _dt(t.createdAt),
          },
      ],
      'pets': result,
    };
  }

  /// Writes the snapshot to a UTF-8 JSON file in the temp dir and returns
  /// the absolute path — caller usually hands it straight to share_plus.
  Future<File> writeSnapshotToTempFile() async {
    final snapshot = await buildSnapshot();
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File(p.join(tmp.path, 'pet_passport_export_$stamp.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot),
    );
    return file;
  }

  Map<String, dynamic> _petToJson(
    Pet pet,
    List<Vet> vets,
    List<Insurance> insurances,
    List<Vaccination> vaccinations,
    List<Event> events,
  ) {
    return {
      'uuid': pet.uuid,
      'name': pet.name,
      'species': _speciesString(pet.species),
      'sex': _sexString(pet.sex),
      'is_neutered': pet.isNeutered,
      'breed': pet.breed,
      'date_of_birth': _dt(pet.dateOfBirth),
      'color': pet.color,
      'markings': pet.markings,
      'chip_number': pet.chipNumber,
      'tasso_number': pet.tassoNumber,
      'tasso_registered_at': _dt(pet.tassoRegisteredAt),
      'vaccination_passport_number': pet.vaccinationPassportNumber,
      'profile_photo_path': pet.profilePhotoPath,
      'allergies': pet.allergies,
      'notes': pet.notes,
      'created_at': _dt(pet.createdAt),
      'updated_at': _dt(pet.updatedAt),
      'weights': [
        for (final w in pet.weights)
          {
            'measured_at': _dt(w.measuredAt),
            'weight_kg': w.weightKg,
            'note': w.note,
          },
      ],
      'vets': [
        for (final v in vets)
          {
            'uuid': v.uuid,
            'name': v.name,
            'practice': v.practice,
            'address': v.address,
            'phone': v.phone,
            'email': v.email,
            'notes': v.notes,
            'created_at': _dt(v.createdAt),
            'updated_at': _dt(v.updatedAt),
          },
      ],
      'insurances': [
        for (final ins in insurances)
          {
            'uuid': ins.uuid,
            'provider': ins.provider,
            'policy_number': ins.policyNumber,
            'contract_start': _dt(ins.contractStart),
            'contract_end': _dt(ins.contractEnd),
            'notes': ins.notes,
            'created_at': _dt(ins.createdAt),
            'updated_at': _dt(ins.updatedAt),
            'documents': [
              for (final d in ins.documents)
                {
                  'uuid': d.uuid,
                  'file_path': d.filePath,
                  'mime_type': d.mimeType,
                  'original_filename': d.originalFilename,
                  'size_bytes': d.sizeBytes,
                  'created_at': _dt(d.createdAt),
                },
            ],
          },
      ],
      'events': [
        for (final e in events)
          {
            'uuid': e.uuid,
            'event_type': _eventTypeString(e.type),
            'occurred_at': _dt(e.occurredAt),
            'title': e.title,
            'note': e.note,
            'payload': e.payload.toJson(),
            'tag_uuids': [for (final t in e.tags) t.uuid],
            'photos': [
              for (final p in e.photos)
                {
                  'uuid': p.uuid,
                  'file_path': p.filePath,
                  'mime_type': p.mimeType,
                  'size_bytes': p.sizeBytes,
                  'created_at': _dt(p.createdAt),
                },
            ],
            'created_at': _dt(e.createdAt),
            'updated_at': _dt(e.updatedAt),
          },
      ],
      'vaccinations': [
        for (final vac in vaccinations)
          {
            'uuid': vac.uuid,
            'vaccine_name': vac.vaccineName,
            'administered_at': _dt(vac.administeredAt),
            'next_due_at': _dt(vac.nextDueAt),
            'vet_uuid': vac.vetUuid,
            'batch_number': vac.batchNumber,
            'notes': vac.notes,
            'created_at': _dt(vac.createdAt),
            'updated_at': _dt(vac.updatedAt),
            'documents': [
              for (final d in vac.documents)
                {
                  'uuid': d.uuid,
                  'file_path': d.filePath,
                  'mime_type': d.mimeType,
                  'original_filename': d.originalFilename,
                  'size_bytes': d.sizeBytes,
                  'created_at': _dt(d.createdAt),
                },
            ],
          },
      ],
    };
  }

  String? _dt(DateTime? dt) => dt?.toUtc().toIso8601String();

  String _speciesString(Species s) => switch (s) {
        Species.dog => 'dog',
        Species.cat => 'cat',
      };

  String _sexString(Sex s) => switch (s) {
        Sex.male => 'male',
        Sex.female => 'female',
      };

  String _eventTypeString(EventType t) => switch (t) {
        EventType.weight => 'weight',
        EventType.feeding => 'feeding',
        EventType.symptom => 'symptom',
        EventType.activity => 'activity',
        EventType.generic => 'generic',
      };
}

