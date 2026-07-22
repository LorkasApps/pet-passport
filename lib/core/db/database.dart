import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/pets/domain/pet_enums.dart';
import 'daos/insurances_dao.dart';
import 'daos/pets_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/vaccinations_dao.dart';
import 'daos/vets_dao.dart';
import 'tables/app_settings_table.dart';
import 'tables/insurance_documents_table.dart';
import 'tables/insurances_table.dart';
import 'tables/pet_weights_table.dart';
import 'tables/pets_table.dart';
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
  ],
  daos: [PetsDao, VetsDao, InsurancesDao, VaccinationsDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

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
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'pet_passport');
  }
}
