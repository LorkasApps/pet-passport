import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:printing/printing.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../application/pdf_providers.dart';
import '../data/pdf_builders.dart';

typedef _Builder = Future<pw.Document> Function(PdfBundle);

class PdfMenuScreen extends ConsumerWidget {
  const PdfMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.pdfMenuTitle)),
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
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _PdfTile(
                icon: Icons.vaccines_outlined,
                title: l.pdfPassportTitle,
                subtitle: l.pdfPassportSubtitle,
                builder: buildVaccinationPassport,
                filename: 'impfpass_${pet.name}.pdf',
              ),
              _PdfTile(
                icon: Icons.description_outlined,
                title: l.pdfOverviewTitle,
                subtitle: l.pdfOverviewSubtitle,
                builder: buildPetOverview,
                filename: 'uebersicht_${pet.name}.pdf',
              ),
              _PdfTile(
                icon: Icons.medical_information_outlined,
                title: l.pdfEmergencyTitle,
                subtitle: l.pdfEmergencySubtitle,
                builder: buildEmergencySheet,
                filename: 'notfall_${pet.name}.pdf',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PdfTile extends ConsumerWidget {
  const _PdfTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
    required this.filename,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _Builder builder;
  final String filename;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    // Snapshot everything context-dependent before the first await so we
    // don't hop across an async gap with a stale BuildContext.
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final pet = await ref.read(currentPetProvider.future);
    if (pet == null) return;
    final bundle = await ref
        .read(pdfServiceProvider)
        .loadBundle(petUuid: pet.uuid, locale: locale, l: l);
    if (bundle == null) return;
    final doc = await builder(bundle);
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: filename,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.picture_as_pdf_outlined),
      onTap: () => _open(context, ref),
    );
  }
}
