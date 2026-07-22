import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../../pets/application/pets_providers.dart';
import '../../pets/domain/pet.dart';
import '../../pets/presentation/widgets/pet_avatar.dart';
import '../../vets/application/vets_providers.dart';
import '../../vets/domain/vet.dart';
import 'emergency_qr_card.dart';

class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.emergencyTitle)),
      body: petAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pet) {
          if (pet == null) {
            return EmptyState(
              icon: Icons.pets_outlined,
              title: l.petsListEmpty,
            );
          }
          final vetsAsync = ref.watch(vetsForPetProvider(pet.uuid));
          final weightAsync =
              ref.watch(latestWeightForPetProvider(pet.uuid));
          final weight = weightAsync.valueOrNull;
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              _PetHeader(pet: pet),
              const SizedBox(height: 16),
              _IdentitySection(pet: pet, l: l),
              if (pet.allergies != null && pet.allergies!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: scheme.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.warning_amber_outlined,
                        color: scheme.onErrorContainer),
                    title: Text(
                      l.petFieldAllergies,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                    subtitle: Text(
                      pet.allergies!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ),
              ],
              if (weight != null) ...[
                const SizedBox(height: 12),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListTile(
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: Text(l.emergencyWeightTitle),
                    subtitle: Text(
                      l.emergencyWeightValue(
                        weight.weightKg.toStringAsFixed(1),
                        DateFormat.yMd(
                                Localizations.localeOf(context).toString())
                            .format(weight.measuredAt),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _VetsSection(vets: vetsAsync.valueOrNull ?? const [], l: l),
              if (pet.notes != null && pet.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListTile(
                    leading: const Icon(Icons.notes_outlined),
                    title: Text(l.petFieldNotes),
                    subtitle: Text(pet.notes!),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              EmergencyQrCard(
                pet: pet,
                vets: vetsAsync.valueOrNull ?? const [],
                latestWeightKg: weight?.weightKg,
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _PetHeader extends StatelessWidget {
  const _PetHeader({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PetAvatar(pet: pet, radius: 48),
        const SizedBox(height: 12),
        Text(
          pet.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ],
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.pet, required this.l});

  final Pet pet;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (pet.chipNumber != null && pet.chipNumber!.isNotEmpty) {
      rows.add(_copyTile(context, Icons.qr_code_2_outlined,
          l.petFieldChipNumber, pet.chipNumber!, l));
    }
    if (pet.tassoNumber != null && pet.tassoNumber!.isNotEmpty) {
      rows.add(_copyTile(context, Icons.confirmation_number_outlined,
          l.petFieldTassoNumber, pet.tassoNumber!, l));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: rows),
    );
  }

  Widget _copyTile(BuildContext context, IconData icon, String label,
      String value, AppL10n l) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.copy, size: 18),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.copiedToClipboard)),
          );
        }
      },
    );
  }
}

class _VetsSection extends StatelessWidget {
  const _VetsSection({required this.vets, required this.l});

  final List<Vet> vets;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    if (vets.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l.emergencyVetsSection,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final v in vets) _VetRow(vet: v, l: l),
        ],
      ),
    );
  }
}

class _VetRow extends StatelessWidget {
  const _VetRow({required this.vet, required this.l});

  final Vet vet;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final phone = vet.phone;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(Icons.medical_services_outlined,
            color: scheme.onSecondaryContainer),
      ),
      title: Text(vet.name),
      subtitle: phone == null || phone.isEmpty
          ? Text(vet.practice ?? '')
          : Text(phone),
      trailing: phone == null || phone.isEmpty
          ? null
          : FilledButton.tonalIcon(
              onPressed: () => _call(context, phone, l),
              icon: const Icon(Icons.phone),
              label: Text(l.emergencyCallAction),
            ),
    );
  }

  Future<void> _call(BuildContext context, String phone, AppL10n l) async {
    final uri = Uri(
      scheme: 'tel',
      path: phone.replaceAll(RegExp(r'[^\d+]'), ''),
    );
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.launchFailed)),
      );
    }
  }
}
