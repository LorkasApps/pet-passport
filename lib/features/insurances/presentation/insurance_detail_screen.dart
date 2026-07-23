import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../pets/application/pets_providers.dart';
import '../application/insurances_providers.dart';
import '../domain/insurance.dart';

class InsuranceDetailScreen extends ConsumerWidget {
  const InsuranceDetailScreen({
    super.key,
    required this.petUuid,
    required this.insuranceUuid,
  });

  final String petUuid;
  final String insuranceUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(insuranceByUuidProvider(
      (insuranceUuid: insuranceUuid, petUuid: petUuid),
    ));
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (ins) {
        if (ins == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('—')),
          );
        }
        return _InsuranceDetailContent(
          insurance: ins,
          petUuid: petUuid,
        );
      },
    );
  }
}

class _InsuranceDetailContent extends ConsumerWidget {
  const _InsuranceDetailContent({
    required this.insurance,
    required this.petUuid,
  });

  final Insurance insurance;
  final String petUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(insurance.provider),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l.actionEdit,
            onPressed: () => context.push(
              '/pets/$petUuid/insurances/${insurance.uuid}/edit',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (insurance.policyNumber != null &&
              insurance.policyNumber!.isNotEmpty)
            _copyableTile(
              context: context,
              icon: Icons.numbers_outlined,
              label: l.insuranceFieldPolicy,
              value: insurance.policyNumber!,
              l: l,
            ),
          if (insurance.contractStart != null)
            _readOnlyTile(
              context: context,
              icon: Icons.event_outlined,
              label: l.insuranceFieldContractStart,
              value: DateFormat.yMd(locale).format(insurance.contractStart!),
            ),
          if (insurance.contractEnd != null)
            _readOnlyTile(
              context: context,
              icon: Icons.event_busy_outlined,
              label: l.insuranceFieldContractEnd,
              value: DateFormat.yMd(locale).format(insurance.contractEnd!),
            ),
          if (insurance.notes != null && insurance.notes!.isNotEmpty)
            _readOnlyTile(
              context: context,
              icon: Icons.notes_outlined,
              label: l.petFieldNotes,
              value: insurance.notes!,
            ),
          const SizedBox(height: 8),
          _documentsSection(context, ref, l),
        ],
      ),
    );
  }

  Widget _documentsSection(
    BuildContext context,
    WidgetRef ref,
    AppL10n l,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                l.insuranceDocumentsSection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (insurance.documents.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  l.insuranceDocumentsEmpty,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final doc in insurance.documents)
                ListTile(
                  leading: Icon(
                    doc.mimeType == 'application/pdf'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    doc.displayName(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: doc.sizeBytes == null
                      ? null
                      : Text(_formatSize(doc.sizeBytes!)),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openDocument(context, ref, doc.filePath),
                ),
          ],
        ),
      ),
    );
  }

  Widget _copyableTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required AppL10n l,
  }) {
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

  Widget _readOnlyTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.outline),
      title: Text(label),
      subtitle: Text(value),
    );
  }

  Future<void> _openDocument(
    BuildContext context,
    WidgetRef ref,
    String relativePath,
  ) async {
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
