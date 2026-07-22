import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../application/current_pet_provider.dart';
import '../application/pets_providers.dart';
import '../domain/pet.dart';
import '../domain/pet_passport_document.dart';

class PassportScreen extends ConsumerStatefulWidget {
  const PassportScreen({super.key});

  @override
  ConsumerState<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends ConsumerState<PassportScreen> {
  final _numberCtrl = TextEditingController();
  String? _lastPrefilledUuid;
  bool _dirty = false;
  bool _saving = false;

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  void _prefill(Pet pet) {
    if (_lastPrefilledUuid == pet.uuid) return;
    _lastPrefilledUuid = pet.uuid;
    _numberCtrl.text = pet.vaccinationPassportNumber ?? '';
    _dirty = false;
  }

  Future<void> _saveNumber(String petUuid) async {
    setState(() => _saving = true);
    try {
      final trimmed = _numberCtrl.text.trim();
      await ref.read(petsRepositoryProvider).updatePassportNumber(
            petUuid: petUuid,
            number: trimmed.isEmpty ? null : trimmed,
          );
      _dirty = false;
      if (mounted) {
        final l = AppL10n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.passportNumberSavedSnack)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _attachDoc(String petUuid) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) return;
    await ref.read(petsRepositoryProvider).attachPassportDoc(
          petUuid: petUuid,
          source: File(path),
          mimeType: _mimeFor(file.extension),
          originalFilename: file.name,
          sizeBytes: file.size,
        );
  }

  Future<void> _openDoc(String relativePath) async {
    final absolute = await ref.read(mediaServiceProvider).resolve(relativePath);
    final result = await OpenFilex.open(absolute);
    if (result.type != ResultType.done && mounted) {
      final l = AppL10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.launchFailed)),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.passportTitle)),
      body: petAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pet) {
          if (pet == null) {
            return Center(child: Text(l.petsListEmpty));
          }
          _prefill(pet);
          final docsAsync = ref.watch(passportDocsForPetProvider(pet.uuid));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _numberCtrl,
                decoration: InputDecoration(
                  labelText: l.passportNumberLabel,
                  helperText: l.passportNumberHelp,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (!_dirty) setState(() => _dirty = true);
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: !_dirty || _saving
                      ? null
                      : () => _saveNumber(pet.uuid),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l.actionSave),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.passportDocumentsSection,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _attachDoc(pet.uuid),
                    icon: const Icon(Icons.attach_file),
                    label: Text(l.actionAdd),
                  ),
                ],
              ),
              docsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) => Text('$e'),
                data: (docs) {
                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        l.passportDocumentsEmpty,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [for (final d in docs) _docTile(d, l)],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _docTile(PetPassportDocument d, AppL10n l) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        d.mimeType == 'application/pdf'
            ? Icons.picture_as_pdf_outlined
            : Icons.image_outlined,
      ),
      title: Text(
        d.originalFilename ?? d.uuid,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: d.sizeBytes == null ? null : Text(_formatSize(d.sizeBytes!)),
      onTap: () => _openDoc(d.filePath),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l.actionDelete,
        onPressed: () =>
            ref.read(petsRepositoryProvider).removePassportDoc(d.uuid),
      ),
    );
  }
}
