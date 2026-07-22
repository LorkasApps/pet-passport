import 'package:flutter/material.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../pets/domain/pet.dart';
import '../../pets/domain/pet_enums.dart';
import '../../vets/domain/vet.dart';

class EmergencyQrCard extends StatelessWidget {
  const EmergencyQrCard({
    super.key,
    required this.pet,
    required this.vets,
    this.latestWeightKg,
  });

  final Pet pet;
  final List<Vet> vets;
  final double? latestWeightKg;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final payload = _buildPayload(pet, vets, l, latestWeightKg);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.emergencyQrTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openFullscreen(context, payload, pet),
                  icon: const Icon(Icons.fullscreen),
                  label: Text(l.emergencyQrExpand),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.emergencyQrHelp,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Center(
              child: _qr(context, payload, size: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qr(BuildContext context, String data, {required double size}) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      // Improves scannability if the string overflows a single QR version.
      gapless: false,
    );
  }

  Future<void> _openFullscreen(
      BuildContext context, String data, Pet pet) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenQr(payload: data, petName: pet.name),
      ),
    );
  }

  static String _buildPayload(
    Pet pet,
    List<Vet> vets,
    AppL10n l,
    double? latestWeightKg,
  ) {
    final b = StringBuffer();
    b.writeln('${l.appTitle} — ${pet.name}');
    b.writeln('${_speciesLabel(pet.species, l)}${pet.breed != null && pet.breed!.isNotEmpty ? ', ${pet.breed}' : ''}');
    if (pet.chipNumber != null && pet.chipNumber!.isNotEmpty) {
      b.writeln('${l.petFieldChipNumber}: ${pet.chipNumber}');
    }
    if (pet.tassoNumber != null && pet.tassoNumber!.isNotEmpty) {
      b.writeln('${l.petFieldTassoNumber}: ${pet.tassoNumber}');
    }
    if (pet.allergies != null && pet.allergies!.isNotEmpty) {
      b.writeln('${l.petFieldAllergies}: ${pet.allergies}');
    }
    if (latestWeightKg != null) {
      b.writeln('${l.emergencyWeightTitle}: ${latestWeightKg.toStringAsFixed(1)} kg');
    }
    if (vets.isNotEmpty) {
      b.writeln();
      b.writeln('${l.vetsListTitle}:');
      for (final v in vets) {
        b.write('- ${v.name}');
        if (v.practice != null && v.practice!.isNotEmpty) {
          b.write(' (${v.practice})');
        }
        b.writeln();
        if (v.phone != null && v.phone!.isNotEmpty) {
          b.writeln('  ${l.vetFieldPhone}: ${v.phone}');
        }
      }
    }
    return b.toString();
  }

  static String _speciesLabel(Species s, AppL10n l) {
    return switch (s) {
      Species.dog => l.speciesDog,
      Species.cat => l.speciesCat,
    };
  }
}

class _FullscreenQr extends StatelessWidget {
  const _FullscreenQr({required this.payload, required this.petName});

  final String payload;
  final String petName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(petName)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest.shortestSide;
                      return QrImageView(
                        data: payload,
                        version: QrVersions.auto,
                        size: size,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                payload,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
