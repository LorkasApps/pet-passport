import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../pets/application/pets_providers.dart';
import '../../vets/application/vets_providers.dart';
import '../application/vaccinations_providers.dart';
import '../domain/vaccination.dart';

class VaccinationDetailScreen extends ConsumerWidget {
  const VaccinationDetailScreen({
    super.key,
    required this.petUuid,
    required this.vaccinationUuid,
  });

  final String petUuid;
  final String vaccinationUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vaccinationByUuidProvider(
      (vaccinationUuid: vaccinationUuid, petUuid: petUuid),
    ));
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (vac) {
        if (vac == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('—')),
          );
        }
        return _Content(vaccination: vac, petUuid: petUuid);
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.vaccination, required this.petUuid});

  final Vaccination vaccination;
  final String petUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final vetsAsync = ref.watch(vetsForPetProvider(petUuid));
    final vetName = vaccination.vetUuid == null
        ? null
        : vetsAsync.valueOrNull
            ?.where((v) => v.uuid == vaccination.vetUuid)
            .firstOrNull
            ?.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(vaccination.vaccineName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l.actionEdit,
            onPressed: () => context.push(
              '/pets/$petUuid/vaccinations/${vaccination.uuid}/edit',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (vaccination.isOverdue)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_outlined,
                          color: scheme.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.vaccinationOverdueMessage,
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ListTile(
            leading: Icon(Icons.event_outlined, color: scheme.primary),
            title: Text(l.vaccinationFieldAdministered),
            subtitle: Text(
                DateFormat.yMd(locale).format(vaccination.administeredAt)),
          ),
          if (vaccination.nextDueAt != null)
            ListTile(
              leading: Icon(
                Icons.event_available_outlined,
                color:
                    vaccination.isOverdue ? scheme.error : scheme.primary,
              ),
              title: Text(l.vaccinationFieldNextDue),
              subtitle: Text(
                  DateFormat.yMd(locale).format(vaccination.nextDueAt!)),
            ),
          if (vetName != null)
            ListTile(
              leading:
                  Icon(Icons.medical_services_outlined, color: scheme.primary),
              title: Text(l.vaccinationFieldVet),
              subtitle: Text(vetName),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => context.push(
                  '/pets/$petUuid/vets/${vaccination.vetUuid}'),
            ),
          if (vaccination.batchNumber != null &&
              vaccination.batchNumber!.isNotEmpty)
            ListTile(
              leading: Icon(Icons.qr_code_2_outlined, color: scheme.outline),
              title: Text(l.vaccinationFieldBatch),
              subtitle: Text(vaccination.batchNumber!),
            ),
          if (vaccination.notes != null && vaccination.notes!.isNotEmpty)
            ListTile(
              leading: Icon(Icons.notes_outlined, color: scheme.outline),
              title: Text(l.petFieldNotes),
              subtitle: Text(vaccination.notes!),
            ),
          if (vaccination.documents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        l.vaccinationDocumentsSection,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final doc in vaccination.documents)
                      ListTile(
                        leading: Icon(
                          doc.mimeType == 'application/pdf'
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                          color: scheme.primary,
                        ),
                        title: Text(
                          doc.originalFilename ?? doc.uuid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () =>
                            _openDoc(context, ref, doc.filePath),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openDoc(
      BuildContext context, WidgetRef ref, String relativePath) async {
    final l = AppL10n.of(context);
    final absolute =
        await ref.read(mediaServiceProvider).resolve(relativePath);
    final result = await OpenFilex.open(absolute);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.launchFailed)),
      );
    }
  }
}
