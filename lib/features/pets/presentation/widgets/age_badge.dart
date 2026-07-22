import 'package:flutter/material.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../domain/life_stage.dart';
import '../../domain/pet.dart';
import '../../domain/pet_enums.dart';

class AgeBadge extends StatelessWidget {
  const AgeBadge({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dob = pet.dateOfBirth;
    if (dob == null) {
      return _pill(scheme, l.ageUnknown);
    }
    final now = DateTime.now();
    final months = LifeStageCalculator.ageInMonths(dob, now);
    final stage = LifeStageCalculator.compute(
      species: pet.species,
      dateOfBirth: dob,
      now: now,
    );
    final ageLabel = months < 24
        ? l.ageMonths(months)
        : l.ageYears(months ~/ 12);
    final stageLabel = stage != null ? ' · ${_stageLabel(l, stage)}' : '';
    return _pill(scheme, '$ageLabel$stageLabel');
  }

  Widget _pill(ColorScheme scheme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _stageLabel(AppL10n l, LifeStage stage) {
    return switch (stage) {
      LifeStage.puppy => l.lifeStagePuppy,
      LifeStage.junior => l.lifeStageJunior,
      LifeStage.adult => l.lifeStageAdult,
      LifeStage.senior => l.lifeStageSenior,
    };
  }
}
