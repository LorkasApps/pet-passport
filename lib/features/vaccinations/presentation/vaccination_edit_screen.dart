import 'dart:io';

import 'package:file_picker/file_picker.dart';
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

class VaccinationEditScreen extends ConsumerStatefulWidget {
  const VaccinationEditScreen({
    super.key,
    required this.petUuid,
    this.vaccinationUuid,
  });

  final String petUuid;
  final String? vaccinationUuid;

  bool get isEdit => vaccinationUuid != null;

  @override
  ConsumerState<VaccinationEditScreen> createState() =>
      _VaccinationEditScreenState();
}

class _VaccinationEditScreenState
    extends ConsumerState<VaccinationEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _administered = DateTime.now();
  DateTime? _nextDue;
  String? _vetUuid;
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _batchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _prefill(Vaccination v) {
    if (_prefilled) return;
    _prefilled = true;
    _nameCtrl.text = v.vaccineName;
    _batchCtrl.text = v.batchNumber ?? '';
    _notesCtrl.text = v.notes ?? '';
    _administered = v.administeredAt;
    _nextDue = v.nextDueAt;
    _vetUuid = v.vetUuid;
  }

  String? _emptyToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickAdministered() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _administered,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (picked != null) setState(() => _administered = picked);
  }

  Future<void> _pickNextDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDue ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _nextDue = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(vaccinationsRepositoryProvider);
      final name = _nameCtrl.text.trim();
      final batch = _emptyToNull(_batchCtrl.text);
      final notes = _emptyToNull(_notesCtrl.text);
      if (widget.isEdit) {
        await repo.updateVaccination(
          uuid: widget.vaccinationUuid!,
          vaccineName: name,
          administeredAt: _administered,
          nextDueAt: _nextDue,
          vetUuid: _vetUuid,
          batchNumber: batch,
          notes: notes,
        );
      } else {
        await repo.createVaccination(
          petUuid: widget.petUuid,
          vaccineName: name,
          administeredAt: _administered,
          nextDueAt: _nextDue,
          vetUuid: _vetUuid,
          batchNumber: batch,
          notes: notes,
        );
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _documentsSection(
    BuildContext context,
    AppL10n l,
    Vaccination vac,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.vaccinationDocumentsSection,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _attachDocument,
                    icon: const Icon(Icons.attach_file),
                    label: Text(l.actionAdd),
                  ),
                ],
              ),
            ),
            if (vac.documents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l.vaccinationDocumentsEmpty,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final doc in vac.documents)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    doc.mimeType == 'application/pdf'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                  ),
                  title: Text(
                    doc.originalFilename ?? doc.uuid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: doc.sizeBytes == null
                      ? null
                      : Text(_formatSize(doc.sizeBytes!)),
                  onTap: () => _openDoc(context, doc.filePath),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref
                        .read(vaccinationsRepositoryProvider)
                        .removeDocument(doc.uuid),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _attachDocument() async {
    if (!widget.isEdit) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) return;
    await ref.read(vaccinationsRepositoryProvider).attachDocument(
          vaccinationUuid: widget.vaccinationUuid!,
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

  Future<void> _openDoc(BuildContext context, String relativePath) async {
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

  Future<void> _confirmDelete(AppL10n l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.confirmDeleteTitle),
        content: Text(l.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(vaccinationsRepositoryProvider)
        .deleteByUuid(widget.vaccinationUuid!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final title = widget.isEdit
        ? l.vaccinationEditEditTitle
        : l.vaccinationEditNewTitle;

    if (widget.isEdit) {
      final async = ref.watch(vaccinationByUuidProvider(
        (
          vaccinationUuid: widget.vaccinationUuid!,
          petUuid: widget.petUuid,
        ),
      ));
      return async.when(
        loading: () => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(child: Text('$e')),
        ),
        data: (v) {
          if (v == null) {
            return Scaffold(appBar: AppBar(title: Text(title)));
          }
          _prefill(v);
          return _buildScaffold(context, title, l, v);
        },
      );
    }
    return _buildScaffold(context, title, l, null);
  }

  Widget _buildScaffold(
    BuildContext context,
    String title,
    AppL10n l,
    Vaccination? vaccination,
  ) {
    final vetsAsync = ref.watch(vetsForPetProvider(widget.petUuid));
    final vets = vetsAsync.valueOrNull ?? const [];
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : () => _confirmDelete(l),
              tooltip: l.actionDelete,
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(l.actionSave),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration:
                  InputDecoration(labelText: l.vaccinationFieldName),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l.validationRequired
                  : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickAdministered,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.vaccinationFieldAdministered,
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(DateFormat.yMd(locale).format(_administered)),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickNextDue,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.vaccinationFieldNextDue,
                  suffixIcon: _nextDue == null
                      ? const Icon(Icons.calendar_today, size: 18)
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _nextDue = null),
                        ),
                ),
                child: Text(
                  _nextDue == null
                      ? '—'
                      : DateFormat.yMd(locale).format(_nextDue!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _vetUuid,
              decoration:
                  InputDecoration(labelText: l.vaccinationFieldVet),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l.vaccinationVetNone),
                ),
                for (final v in vets)
                  DropdownMenuItem<String?>(
                    value: v.uuid,
                    child: Text(v.name),
                  ),
              ],
              onChanged: (v) => setState(() => _vetUuid = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _batchCtrl,
              decoration:
                  InputDecoration(labelText: l.vaccinationFieldBatch),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: l.petFieldNotes),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            if (widget.isEdit && vaccination != null) ...[
              _documentsSection(context, l, vaccination),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.actionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
