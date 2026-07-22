import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../pets/application/current_pet_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    final petUuid = petAsync.valueOrNull?.uuid;
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.event_outlined),
          title: Text(l.moreAppointments),
          onTap: () => context.push('/appointments'),
        ),
        ListTile(
          leading: const Icon(Icons.medication_outlined),
          title: Text(l.moreMedications),
          onTap: () => context.push('/medications'),
        ),
        ListTile(
          leading: const Icon(Icons.restaurant_outlined),
          title: Text(l.moreDiet),
          onTap: () => context.push('/diet'),
        ),
        ListTile(
          leading: const Icon(Icons.show_chart),
          title: Text(l.moreWeightChart),
          enabled: petUuid != null,
          onTap: petUuid == null
              ? null
              : () => context.push('/pets/$petUuid/charts/weight'),
        ),
        ListTile(
          leading: const Icon(Icons.vaccines_outlined),
          title: Text(l.vaccinationsListTitle),
          onTap: () => context.push('/vaccinations'),
        ),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(l.passportTitle),
          onTap: () => context.push('/passport'),
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
          leading: const Icon(Icons.timeline_outlined),
          title: Text(l.moreTimeline),
          onTap: () => context.push('/timeline'),
        ),
        ListTile(
          leading: const Icon(Icons.medical_information_outlined),
          title: Text(l.emergencyTitle),
          onTap: () => context.push('/emergency'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.picture_as_pdf_outlined),
          title: Text(l.morePdf),
          onTap: () => context.push('/pdf'),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share),
          title: Text(l.exportTitle),
          onTap: () => context.push('/export'),
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
