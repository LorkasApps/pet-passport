import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/pets_providers.dart';
import '../../domain/pet.dart';
import '../../domain/pet_enums.dart';

class PetAvatar extends ConsumerWidget {
  const PetAvatar({super.key, required this.pet, this.radius = 24});

  final Pet pet;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final path = pet.profilePhotoPath;
    if (path == null || path.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.secondaryContainer,
        child: Icon(
          _fallbackIcon(pet.species),
          size: radius,
          color: scheme.onSecondaryContainer,
        ),
      );
    }
    return FutureBuilder<String>(
      future: ref.read(mediaServiceProvider).resolve(path),
      builder: (context, snap) {
        if (!snap.hasData) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: scheme.secondaryContainer,
          );
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: scheme.secondaryContainer,
          backgroundImage: FileImage(File(snap.data!)),
        );
      },
    );
  }

  IconData _fallbackIcon(Species species) {
    return switch (species) {
      Species.dog => Icons.pets,
      Species.cat => Icons.pets,
    };
  }
}
