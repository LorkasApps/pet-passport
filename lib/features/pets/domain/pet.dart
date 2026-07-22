import 'package:flutter/foundation.dart';

import 'pet_enums.dart';

@immutable
class Pet {
  const Pet({
    required this.uuid,
    required this.name,
    required this.species,
    required this.sex,
    this.isNeutered = false,
    this.breed,
    this.dateOfBirth,
    this.color,
    this.markings,
    this.chipNumber,
    this.tassoNumber,
    this.tassoRegisteredAt,
    this.vaccinationPassportNumber,
    this.profilePhotoPath,
    this.allergies,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.weights = const [],
  });

  final String uuid;
  final String name;
  final Species species;
  final Sex sex;
  final bool isNeutered;
  final String? breed;
  final DateTime? dateOfBirth;
  final String? color;
  final String? markings;
  final String? chipNumber;
  final String? tassoNumber;
  final DateTime? tassoRegisteredAt;
  final String? vaccinationPassportNumber;
  final String? profilePhotoPath;
  final String? allergies;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<PetWeight> weights;

  Pet copyWith({
    String? name,
    Species? species,
    Sex? sex,
    bool? isNeutered,
    String? Function()? breed,
    DateTime? Function()? dateOfBirth,
    String? Function()? color,
    String? Function()? markings,
    String? Function()? chipNumber,
    String? Function()? tassoNumber,
    DateTime? Function()? tassoRegisteredAt,
    String? Function()? vaccinationPassportNumber,
    String? Function()? profilePhotoPath,
    String? Function()? allergies,
    String? Function()? notes,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
    List<PetWeight>? weights,
  }) {
    return Pet(
      uuid: uuid,
      name: name ?? this.name,
      species: species ?? this.species,
      sex: sex ?? this.sex,
      isNeutered: isNeutered ?? this.isNeutered,
      breed: breed != null ? breed() : this.breed,
      dateOfBirth: dateOfBirth != null ? dateOfBirth() : this.dateOfBirth,
      color: color != null ? color() : this.color,
      markings: markings != null ? markings() : this.markings,
      chipNumber: chipNumber != null ? chipNumber() : this.chipNumber,
      tassoNumber: tassoNumber != null ? tassoNumber() : this.tassoNumber,
      tassoRegisteredAt: tassoRegisteredAt != null
          ? tassoRegisteredAt()
          : this.tassoRegisteredAt,
      vaccinationPassportNumber: vaccinationPassportNumber != null
          ? vaccinationPassportNumber()
          : this.vaccinationPassportNumber,
      profilePhotoPath: profilePhotoPath != null
          ? profilePhotoPath()
          : this.profilePhotoPath,
      allergies: allergies != null ? allergies() : this.allergies,
      notes: notes != null ? notes() : this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
      weights: weights ?? this.weights,
    );
  }
}

@immutable
class PetWeight {
  const PetWeight({
    required this.measuredAt,
    required this.weightKg,
    this.note,
  });

  final DateTime measuredAt;
  final double weightKg;
  final String? note;
}
