import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/application/appointments_providers.dart';
import '../../contacts/application/contacts_providers.dart';
import '../../diet/application/foods_providers.dart';
import '../../insurances/application/insurances_providers.dart';
import '../../medications/application/medications_providers.dart';
import '../../pets/application/pets_providers.dart';
import '../../protocol/application/events_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../vaccinations/application/vaccinations_providers.dart';
import '../../vets/application/vets_providers.dart';
import '../data/export_service.dart';
import '../data/import_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    ref.watch(petsRepositoryProvider),
    ref.watch(vetsRepositoryProvider),
    ref.watch(insurancesRepositoryProvider),
    ref.watch(vaccinationsRepositoryProvider),
    ref.watch(eventsRepositoryProvider),
    ref.watch(appointmentsRepositoryProvider),
    ref.watch(medicationsRepositoryProvider),
    ref.watch(foodsRepositoryProvider),
    ref.watch(contactsRepositoryProvider),
  );
});

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(ref.watch(databaseProvider));
});
