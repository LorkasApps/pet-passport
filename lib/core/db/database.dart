import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/appointments/domain/appointment_enums.dart';
import '../../features/contacts/domain/contact_enums.dart';
import '../../features/diet/domain/food_enums.dart';
import '../../features/medications/domain/medication_enums.dart';
import '../../features/pets/domain/pet_enums.dart';
import '../../features/protocol/domain/event_enums.dart';
import 'daos/appointments_dao.dart';
import 'daos/contacts_dao.dart';
import 'daos/events_dao.dart';
import 'daos/pending_media_ops_dao.dart';
import 'daos/pending_ops_dao.dart';
import 'daos/pet_documents_dao.dart';
import 'daos/foods_dao.dart';
import 'daos/insurances_dao.dart';
import 'daos/medications_dao.dart';
import 'daos/pets_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/sync_cursors_dao.dart';
import 'daos/vaccinations_dao.dart';
import 'daos/vets_dao.dart';
import 'tables/app_settings_table.dart';
import 'tables/appointment_exceptions_table.dart';
import 'tables/appointment_reminders_table.dart';
import 'tables/appointments_table.dart';
import 'tables/contacts_table.dart';
import 'tables/event_photos_table.dart';
import 'tables/event_tag_links_table.dart';
import 'tables/event_tags_table.dart';
import 'tables/events_table.dart';
import 'tables/food_photos_table.dart';
import 'tables/foods_table.dart';
import 'tables/insurance_documents_table.dart';
import 'tables/insurances_table.dart';
import 'tables/medication_intakes_table.dart';
import 'tables/medication_reminders_table.dart';
import 'tables/medications_table.dart';
import 'tables/pending_media_ops_table.dart';
import 'tables/pending_ops_table.dart';
import 'tables/pet_documents_table.dart';
import 'tables/pet_passport_documents_table.dart';
import 'tables/pet_weights_table.dart';
import 'tables/pets_table.dart';
import 'tables/sync_cursors_table.dart';
import 'tables/vaccination_documents_table.dart';
import 'tables/vaccinations_table.dart';
import 'tables/vets_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Pets,
    PetWeights,
    Vets,
    Insurances,
    InsuranceDocuments,
    Vaccinations,
    VaccinationDocuments,
    AppSettings,
    Events,
    EventTags,
    EventTagLinks,
    EventPhotos,
    Appointments,
    AppointmentReminders,
    AppointmentExceptions,
    Medications,
    MedicationReminders,
    MedicationIntakes,
    Foods,
    FoodPhotos,
    PetPassportDocuments,
    Contacts,
    PetDocuments,
    PendingOps,
    PendingMediaOps,
    SyncCursors,
  ],
  daos: [
    PetsDao,
    VetsDao,
    InsurancesDao,
    VaccinationsDao,
    SettingsDao,
    EventsDao,
    AppointmentsDao,
    MedicationsDao,
    FoodsDao,
    ContactsDao,
    PetDocumentsDao,
    PendingOpsDao,
    PendingMediaOpsDao,
    SyncCursorsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(vets);
            await m.createTable(insurances);
            await m.createTable(insuranceDocuments);
          }
          if (from < 3) {
            await m.addColumn(pets, pets.isNeutered);
            // Legacy: sex=2 used to mean "neuter". Move that into
            // is_neutered and default the actual sex to male (0) since
            // the historical enum did not track it separately.
            await customStatement(
              'UPDATE pets SET is_neutered = 1, sex = 0 WHERE sex = 2',
            );
          }
          if (from < 4) {
            await m.createTable(vaccinations);
          }
          if (from < 5) {
            await m.createTable(vaccinationDocuments);
          }
          if (from < 6) {
            await m.addColumn(pets, pets.allergies);
          }
          if (from < 7) {
            await m.createTable(events);
            await m.createTable(eventTags);
            await m.createTable(eventTagLinks);
            await m.createTable(eventPhotos);
            await m.addColumn(petWeights, petWeights.sourceEventUuid);
          }
          if (from < 8) {
            await m.createTable(appointments);
            await m.createTable(appointmentReminders);
            await m.createTable(appointmentExceptions);
            await m.createTable(medications);
            await m.createTable(medicationReminders);
            await m.createTable(medicationIntakes);
          }
          if (from < 9) {
            await m.createTable(foods);
            // `medications` was recreated with the current shape (incl.
            // with_food) in the from<8 block, so only add the column when
            // we're stepping from an existing v8 install.
            if (from >= 8) {
              await m.addColumn(medications, medications.withFood);
            }
          }
          if (from < 10 && to >= 10) {
            await m.addColumn(pets, pets.vaccinationPassportNumber);
            await m.createTable(petPassportDocuments);
          }
          if (from < 11 && to >= 11) {
            await m.addColumn(vets, vets.isActive);
          }
          if (from < 12 && to >= 12) {
            await m.createTable(foodPhotos);
          }
          if (from < 13 && to >= 13) {
            await m.createTable(contacts);
            await m.addColumn(appointments, appointments.contactId);
          }
          if (from < 14 && to >= 14) {
            await m.createTable(petDocuments);
          }
          if (from < 15 && to >= 15) {
            // Rename support: every attachment surface picks up an
            // optional user-editable title. Physical file names stay put.
            await m.addColumn(eventPhotos, eventPhotos.title);
            await m.addColumn(foodPhotos, foodPhotos.title);
            await m.addColumn(
                insuranceDocuments, insuranceDocuments.title);
            await m.addColumn(
                vaccinationDocuments, vaccinationDocuments.title);
            await m.addColumn(
                petPassportDocuments, petPassportDocuments.title);
          }
          if (from < 16 && to >= 16) {
            // M2 sync foundation: household_id, updated_by_user_id, deleted_at
            // as nullable columns on every top-level entity. Pre-cloud users
            // simply carry nulls; a first-login hook stamps existing rows.
            await m.addColumn(pets, pets.householdId);
            await m.addColumn(pets, pets.updatedByUserId);
            await m.addColumn(vets, vets.householdId);
            await m.addColumn(vets, vets.updatedByUserId);
            await m.addColumn(vets, vets.deletedAt);
            await m.addColumn(contacts, contacts.householdId);
            await m.addColumn(contacts, contacts.updatedByUserId);
            await m.addColumn(contacts, contacts.deletedAt);
            await m.addColumn(appointments, appointments.householdId);
            await m.addColumn(appointments, appointments.updatedByUserId);
            await m.addColumn(appointments, appointments.deletedAt);
            await m.addColumn(medications, medications.householdId);
            await m.addColumn(medications, medications.updatedByUserId);
            await m.addColumn(medications, medications.deletedAt);
            await m.addColumn(medicationIntakes, medicationIntakes.householdId);
            await m.addColumn(medicationIntakes, medicationIntakes.updatedByUserId);
            await m.addColumn(medicationIntakes, medicationIntakes.deletedAt);
            await m.addColumn(foods, foods.householdId);
            await m.addColumn(foods, foods.updatedByUserId);
            await m.addColumn(foods, foods.deletedAt);
            await m.addColumn(vaccinations, vaccinations.householdId);
            await m.addColumn(vaccinations, vaccinations.updatedByUserId);
            await m.addColumn(vaccinations, vaccinations.deletedAt);
            await m.addColumn(insurances, insurances.householdId);
            await m.addColumn(insurances, insurances.updatedByUserId);
            await m.addColumn(insurances, insurances.deletedAt);
            await m.addColumn(events, events.householdId);
            await m.addColumn(events, events.updatedByUserId);
            await m.addColumn(events, events.deletedAt);
            await m.addColumn(eventTags, eventTags.householdId);
            await m.addColumn(eventTags, eventTags.updatedByUserId);
            await m.addColumn(eventTags, eventTags.deletedAt);
            await m.addColumn(petWeights, petWeights.householdId);
            await m.addColumn(petWeights, petWeights.updatedByUserId);
            await m.addColumn(petWeights, petWeights.deletedAt);
          }
          if (from < 17 && to >= 17) {
            // M3 sync foundation: outbox + per-table pull cursor. Both
            // are device-local — never syncs itself, so no
            // household_id / updated_by / deleted_at columns here.
            await m.createTable(pendingOps);
            await m.createTable(syncCursors);
          }
          if (from < 18 && to >= 18) {
            // pet_documents was omitted from the v16 M2 rollout — bring
            // it in line so the outbox has something to enqueue when a
            // doc is attached / renamed / removed.
            await m.addColumn(petDocuments, petDocuments.householdId);
            await m.addColumn(petDocuments, petDocuments.updatedByUserId);
            await m.addColumn(petDocuments, petDocuments.deletedAt);
          }
          if (from < 19 && to >= 19) {
            // M5 media sync: cloud-side storage object key column on
            // every table with a file/photo. `file_path` /
            // `profile_photo_path` remain device-local hints; the
            // `*_storage_key` values ride through row-sync.
            await m.addColumn(pets, pets.profilePhotoStorageKey);
            await m.addColumn(petDocuments, petDocuments.storageKey);
          }
          if (from < 20 && to >= 20) {
            // M5 media outbox — parallel to pending_ops. Local-only,
            // never syncs itself.
            await m.createTable(pendingMediaOps);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'pet_passport');
  }
}
