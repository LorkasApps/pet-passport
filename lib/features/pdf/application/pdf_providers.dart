import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../insurances/application/insurances_providers.dart';
import '../../pets/application/pets_providers.dart';
import '../../vaccinations/application/vaccinations_providers.dart';
import '../../vets/application/vets_providers.dart';
import '../data/pdf_service.dart';

final pdfServiceProvider = Provider<PdfService>((ref) {
  return PdfService(
    pets: ref.watch(petsRepositoryProvider),
    vets: ref.watch(vetsRepositoryProvider),
    vaccinations: ref.watch(vaccinationsRepositoryProvider),
    insurances: ref.watch(insurancesRepositoryProvider),
    media: ref.watch(mediaServiceProvider),
  );
});
