import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../insurances/application/insurances_providers.dart';
import '../../pets/application/pets_providers.dart';
import '../../vaccinations/application/vaccinations_providers.dart';
import '../../vets/application/vets_providers.dart';
import '../data/export_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    ref.watch(petsRepositoryProvider),
    ref.watch(vetsRepositoryProvider),
    ref.watch(insurancesRepositoryProvider),
    ref.watch(vaccinationsRepositoryProvider),
  );
});
