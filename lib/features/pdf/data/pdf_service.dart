import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/media/media_service.dart';
import '../../insurances/data/insurances_repository.dart';
import '../../pets/data/pets_repository.dart';
import '../../vaccinations/data/vaccinations_repository.dart';
import '../../vets/data/vets_repository.dart';
import 'pdf_builders.dart';

/// Builds [PdfBundle]s by fanning out to the feature repositories. Kept
/// here (rather than at the widget layer) so tests can drive PDF snapshot
/// content without spinning up a MaterialApp.
class PdfService {
  PdfService({
    required this.pets,
    required this.vets,
    required this.vaccinations,
    required this.insurances,
    required this.media,
  });

  final PetsRepository pets;
  final VetsRepository vets;
  final VaccinationsRepository vaccinations;
  final InsurancesRepository insurances;
  final MediaService media;

  Future<PdfBundle?> loadBundle({
    required String petUuid,
    required String locale,
    required AppL10n l,
  }) async {
    final pet = await pets.getByUuid(petUuid);
    if (pet == null) return null;
    final vetsList = await vets.watchForPetUuid(petUuid).first;
    final vaccList = await vaccinations.watchForPetUuid(petUuid).first;
    final insList = await insurances.watchForPetUuid(petUuid).first;
    final latestWeight = await pets.watchLatestWeightForUuid(petUuid).first;
    final photoAbs = pet.profilePhotoPath == null
        ? null
        : await media.resolve(pet.profilePhotoPath!);
    return PdfBundle(
      pet: pet,
      vaccinations: vaccList,
      vets: vetsList,
      insurances: insList,
      latestWeight: latestWeight,
      profilePhotoAbsPath: photoAbs,
      locale: locale,
      l: l,
    );
  }
}
