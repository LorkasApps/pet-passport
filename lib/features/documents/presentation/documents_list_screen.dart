import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../../sync/presentation/media_resolver.dart';
import '../application/documents_providers.dart';
import '../domain/pet_document.dart';

class DocumentsListScreen extends ConsumerWidget {
  const DocumentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.documentsListTitle)),
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
          final async = ref.watch(petDocumentsProvider(pet.uuid));
          return async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (docs) {
              if (docs.isEmpty) {
                return EmptyState(
                  icon: Icons.folder_outlined,
                  title: l.documentsEmptyTitle,
                  message: l.documentsEmptyMessage,
                  actionLabel: l.documentsEmptyAction,
                  onAction: () => _pickAndAttach(context, ref, pet.uuid),
                );
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, _) => const Divider(height: 0),
                itemBuilder: (context, i) =>
                    _DocTile(doc: docs[i], petUuid: pet.uuid),
              );
            },
          );
        },
      ),
      floatingActionButton: petAsync.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'documents-fab',
              onPressed: () =>
                  _pickAndAttach(context, ref, petAsync.value!.uuid),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(l.documentsAddAction),
            ),
    );
  }
}

Future<void> _pickAndAttach(
  BuildContext context,
  WidgetRef ref,
  String petUuid,
) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
  );
  if (result == null || result.files.isEmpty) return;
  final file = result.files.single;
  final path = file.path;
  if (path == null) return;
  await ref.read(documentsRepositoryProvider).attach(
        petUuid: petUuid,
        source: File(path),
        mimeType: _mimeFor(file.extension),
        originalFilename: file.name,
        sizeBytes: file.size,
      );
}

String _mimeFor(String? ext) {
  switch (ext?.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _DocTile extends ConsumerWidget {
  const _DocTile({required this.doc, required this.petUuid});

  final PetDocument doc;
  final String petUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final isPdf = doc.mimeType == 'application/pdf';
    final subtitleParts = <String>[
      DateFormat.yMd(locale).format(doc.createdAt),
      if (doc.sizeBytes != null) _formatSize(doc.sizeBytes!),
    ];
    return ListTile(
      leading: Icon(
        isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
        color: scheme.primary,
      ),
      title: Text(
        doc.displayName(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitleParts.join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => openMedia(context, ref, relativePath: doc.filePath, storageKey: doc.storageKey),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'edit':
              await _editDialog(context, ref, doc);
              break;
            case 'delete':
              await _confirmDelete(context, ref, doc, l);
              break;
          }
        },
        itemBuilder: (_) => [
          // 'edit' opens the full title+notes dialog. Keeping the label
          // as 'Bearbeiten' since it edits more than just the title.
          PopupMenuItem(value: 'edit', child: Text(l.actionEdit)),
          PopupMenuItem(value: 'delete', child: Text(l.actionDelete)),
        ],
      ),
    );
  }
}


Future<void> _editDialog(
    BuildContext context, WidgetRef ref, PetDocument doc) async {
  final l = AppL10n.of(context);
  final titleCtrl = TextEditingController(text: doc.title ?? '');
  final notesCtrl = TextEditingController(text: doc.notes ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.documentEditTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleCtrl,
            decoration: InputDecoration(labelText: l.documentFieldTitle),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            decoration: InputDecoration(labelText: l.documentFieldNotes),
            maxLines: 3,
          ),
          if (doc.originalFilename != null &&
              doc.originalFilename!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${l.documentFieldOriginalFilename}: ${doc.originalFilename}',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.actionSave),
        ),
      ],
    ),
  );
  titleCtrl.dispose();
  notesCtrl.dispose();
  if (ok != true) return;
  final trimmedTitle = titleCtrl.text.trim();
  final trimmedNotes = notesCtrl.text.trim();
  await ref.read(documentsRepositoryProvider).updateMetadata(
        uuid: doc.uuid,
        title: trimmedTitle.isEmpty ? null : trimmedTitle,
        notes: trimmedNotes.isEmpty ? null : trimmedNotes,
      );
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, PetDocument doc, AppL10n l) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.confirmDeleteTitle),
      content: Text(l.confirmDeleteMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.actionCancel),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.actionDelete),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(documentsRepositoryProvider).remove(doc.uuid);
}
