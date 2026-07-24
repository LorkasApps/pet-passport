import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/presentation/media_resolver.dart';
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
    final storageKey = pet.profilePhotoStorageKey;
    return Semantics(
      image: true,
      label: pet.name,
      child: _buildAvatar(scheme, path, storageKey),
    );
  }

  Widget _buildAvatar(
    ColorScheme scheme,
    String? path,
    String? storageKey,
  ) {
    // Nothing at all → show the species-icon fallback.
    if ((path == null || path.isEmpty) &&
        (storageKey == null || storageKey.isEmpty)) {
      return _placeholder(scheme, withIcon: true);
    }
    return MediaAsset(
      relativePath: path,
      storageKey: storageKey,
      placeholder: _placeholder(scheme),
      builder: (context, file) => CircleAvatar(
        radius: radius,
        backgroundColor: scheme.secondaryContainer,
        backgroundImage: FileImage(file),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme, {bool withIcon = false}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      child: withIcon
          ? Icon(
              _fallbackIcon(pet.species),
              size: radius,
              color: scheme.onSecondaryContainer,
            )
          : null,
    );
  }

  IconData _fallbackIcon(Species species) {
    return switch (species) {
      Species.dog => Icons.pets,
      Species.cat => Icons.pets,
    };
  }
}
