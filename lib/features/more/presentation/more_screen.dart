import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.vaccines_outlined),
          title: Text(l.vaccinationsListTitle),
          onTap: () => context.push('/vaccinations'),
        ),
        ListTile(
          leading: const Icon(Icons.medical_services_outlined),
          title: Text(l.vetsListTitle),
          onTap: () => context.push('/vets'),
        ),
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: Text(l.insurancesListTitle),
          onTap: () => context.push('/insurances'),
        ),
        ListTile(
          leading: const Icon(Icons.medical_information_outlined),
          title: Text(l.emergencyTitle),
          onTap: () => context.push('/emergency'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.pets_outlined),
          title: Text(l.moreManagePets),
          onTap: () => context.push('/pets'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(l.settingsTitle),
          onTap: () => context.push('/settings'),
        ),
      ],
    );
  }
}
