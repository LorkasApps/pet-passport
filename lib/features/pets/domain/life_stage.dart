import 'pet_enums.dart';

class LifeStageCalculator {
  const LifeStageCalculator._();

  /// Returns a life stage based on age in months and species.
  /// Rough thresholds — not veterinary advice, but good for display.
  static LifeStage? compute({
    required Species species,
    required DateTime? dateOfBirth,
    DateTime? now,
  }) {
    if (dateOfBirth == null) return null;
    final today = now ?? DateTime.now();
    final months = ageInMonths(dateOfBirth, today);
    if (months < 0) return null;

    switch (species) {
      case Species.dog:
        if (months < 12) return LifeStage.puppy;
        if (months < 24) return LifeStage.junior;
        if (months < 84) return LifeStage.adult;
        return LifeStage.senior;
      case Species.cat:
        if (months < 12) return LifeStage.puppy; // kitten uses same key
        if (months < 24) return LifeStage.junior;
        if (months < 120) return LifeStage.adult;
        return LifeStage.senior;
    }
  }

  static int ageInMonths(DateTime dob, DateTime now) {
    var months = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) months -= 1;
    return months;
  }

  static int ageInYears(DateTime dob, DateTime now) =>
      ageInMonths(dob, now) ~/ 12;
}
