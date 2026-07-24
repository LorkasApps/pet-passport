import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../appointments/data/appointments_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../contacts/data/contacts_repository.dart';
import '../../contacts/domain/contact.dart';
import '../../diet/data/foods_repository.dart';
import '../../documents/data/documents_repository.dart';
import '../../documents/domain/pet_document.dart';
import '../../diet/domain/food.dart';
import '../../diet/domain/food_photo.dart';
import '../../insurances/data/insurances_repository.dart';
import '../../insurances/domain/insurance.dart';
import '../../medications/data/medications_repository.dart';
import '../../medications/domain/medication.dart';
import '../../medications/domain/medication_intake.dart';
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
    this._appointments,
    this._medications,
    this._foods,
    this._contacts,
    this._documents,
  );

  final PetsRepository _pets;
  final VetsRepository _vets;
  final InsurancesRepository _insurances;
  final VaccinationsRepository _vaccinations;
  final EventsRepository _events;
  final AppointmentsRepository _appointments;
  final MedicationsRepository _medications;
  final FoodsRepository _foods;
  final ContactsRepository _contacts;
  final DocumentsRepository _documents;

  /// Bumped to 3 in 2026-07 when appointments/medications/foods joined the
  /// snapshot. Older readers see extra keys and ignore them; the import
  /// service accepts v1/v2/v3.
  static const int schemaVersion = 3;
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
      final contacts = await _contacts.watchForPetUuid(pet.uuid).first;
      final documents = await _documents.watchForPetUuid(pet.uuid).first;
      final insurances = await _insurances.watchForPetUuid(pet.uuid).first;
      final vaccinations =
          await _vaccinations.watchForPetUuid(pet.uuid).first;
      final events = await _events.watchForPetUuid(pet.uuid).first;
      final appointments =
          await _appointments.watchForPetUuid(pet.uuid).first;
      final medications = await _medications.watchForPetUuid(pet.uuid).first;
      final foods = await _foods.watchForPetUuid(pet.uuid).first;
      final intakesByMedUuid = <String, List<MedicationIntake>>{};
      for (final m in medications) {
        intakesByMedUuid[m.uuid] =
            await _medications.watchIntakes(m.uuid).first;
      }
      final photosByFoodUuid = <String, List<FoodPhoto>>{};
      for (final f in foods) {
        photosByFoodUuid[f.uuid] = await _foods.watchPhotos(f.uuid).first;
      }
      result.add(_petToJson(
        pet,
        vets,
        contacts,
        insurances,
        vaccinations,
        events,
        appointments,
        medications,
        foods,
        documents,
        intakesByMedUuid,
        photosByFoodUuid,
      ));
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
    List<Contact> contacts,
    List<Insurance> insurances,
    List<Vaccination> vaccinations,
    List<Event> events,
    List<Appointment> appointments,
    List<Medication> medications,
    List<Food> foods,
    List<PetDocument> documents,
    Map<String, List<MedicationIntake>> intakesByMedUuid,
    Map<String, List<FoodPhoto>> photosByFoodUuid,
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
      'chip_number': pet.chipNumber,
      'tasso_number': pet.tassoNumber,
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
            'is_active': v.isActive,
            'created_at': _dt(v.createdAt),
            'updated_at': _dt(v.updatedAt),
          },
      ],
      'contacts': [
        for (final c in contacts)
          {
            'uuid': c.uuid,
            'role': c.role.name,
            'name': c.name,
            'organization': c.organization,
            'address': c.address,
            'phone': c.phone,
            'email': c.email,
            'notes': c.notes,
            'is_active': c.isActive,
            'created_at': _dt(c.createdAt),
            'updated_at': _dt(c.updatedAt),
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
                  'title': d.title,
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
                  'title': p.title,
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
                  'title': d.title,
                  'file_path': d.filePath,
                  'mime_type': d.mimeType,
                  'original_filename': d.originalFilename,
                  'size_bytes': d.sizeBytes,
                  'created_at': _dt(d.createdAt),
                },
            ],
          },
      ],
      'appointments': [
        for (final a in appointments)
          {
            'uuid': a.uuid,
            'type': a.type.name,
            'vet_uuid': a.vetUuid,
            'contact_uuid': a.contactUuid,
            'title': a.title,
            'starts_at': _dt(a.startsAt),
            'duration_minutes': a.durationMinutes,
            'location': a.location,
            'notes': a.notes,
            'recurrence_freq': a.recurrenceFreq.name,
            'recurrence_interval': a.recurrenceInterval,
            'recurrence_weekdays': a.recurrenceWeekdays,
            'recurrence_until': _dt(a.recurrenceUntil),
            'reminder_offsets_minutes': a.reminderOffsetsMinutes,
            'exceptions': [
              for (final ex in a.exceptions)
                {
                  'occurrence_start': _dt(ex.occurrenceStart),
                  'is_cancelled': ex.isCancelled,
                  'override_starts_at': _dt(ex.overrideStartsAt),
                },
            ],
            'created_at': _dt(a.createdAt),
            'updated_at': _dt(a.updatedAt),
          },
      ],
      'medications': [
        for (final m in medications)
          {
            'uuid': m.uuid,
            'name': m.name,
            'dosage_amount': m.dosageAmount,
            'dosage_unit': m.dosageUnit,
            'freq_type': m.freqType.name,
            'freq_interval': m.freqInterval,
            'freq_weekdays': m.freqWeekdays,
            'times_of_day': m.timesOfDay,
            'starts_at': _dt(m.startsAt),
            'ends_at': _dt(m.endsAt),
            'is_active': m.isActive,
            'notes': m.notes,
            'prescribed_by_vet_uuid': m.prescribedByVetUuid,
            'with_food': m.withFood,
            'reminder_offsets_minutes': m.reminderOffsetsMinutes,
            'intakes': [
              for (final i in intakesByMedUuid[m.uuid] ?? const <MedicationIntake>[])
                {
                  'uuid': i.uuid,
                  'taken_at': _dt(i.takenAt),
                  'skipped': i.skipped,
                  'note': i.note,
                },
            ],
            'created_at': _dt(m.createdAt),
            'updated_at': _dt(m.updatedAt),
          },
      ],
      'documents': [
        for (final d in documents)
          {
            'uuid': d.uuid,
            'title': d.title,
            'file_path': d.filePath,
            'mime_type': d.mimeType,
            'original_filename': d.originalFilename,
            'size_bytes': d.sizeBytes,
            'notes': d.notes,
            'created_at': _dt(d.createdAt),
            'updated_at': _dt(d.updatedAt),
          },
      ],
      'foods': [
        for (final f in foods)
          {
            'uuid': f.uuid,
            'brand': f.brand,
            'name': f.name,
            'food_type': f.foodType.name,
            'portion_grams': f.portionGrams,
            'frequency_per_day': f.frequencyPerDay,
            'times_of_day': f.timesOfDay,
            'is_active': f.isActive,
            'starts_at': _dt(f.startsAt),
            'ends_at': _dt(f.endsAt),
            'reminders_enabled': f.remindersEnabled,
            'notes': f.notes,
            'photos': [
              for (final p in photosByFoodUuid[f.uuid] ?? const <FoodPhoto>[])
                {
                  'uuid': p.uuid,
                  'title': p.title,
                  'file_path': p.filePath,
                  'mime_type': p.mimeType,
                  'original_filename': p.originalFilename,
                  'size_bytes': p.sizeBytes,
                  'created_at': _dt(p.createdAt),
                },
            ],
            'created_at': _dt(f.createdAt),
            'updated_at': _dt(f.updatedAt),
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
