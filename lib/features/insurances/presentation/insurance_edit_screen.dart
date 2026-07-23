import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/rename_dialog.dart';
import '../../pets/application/pets_providers.dart';
import '../application/insurances_providers.dart';
import '../domain/insurance.dart';

class InsuranceEditScreen extends ConsumerStatefulWidget {
  const InsuranceEditScreen({
    super.key,
    required this.petUuid,
    this.insuranceUuid,
  });

  final String petUuid;
  final String? insuranceUuid;

  bool get isEdit => insuranceUuid != null;

  @override
  ConsumerState<InsuranceEditScreen> createState() =>
      _InsuranceEditScreenState();
}

class _InsuranceEditScreenState extends ConsumerState<InsuranceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _providerCtrl = TextEditingController();
  final _policyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  // Files picked before this insurance has a uuid — flushed on save.
  final List<_PendingDoc> _pendingDocs = [];
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _providerCtrl.dispose();
    _policyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _prefill(Insurance ins) {
    if (_prefilled) return;
    _prefilled = true;
    _providerCtrl.text = ins.provider;
    _policyCtrl.text = ins.policyNumber ?? '';
    _notesCtrl.text = ins.notes ?? '';
    _start = ins.contractStart;
    _end = ins.contractEnd;
  }

  String? _emptyToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart ? _start ?? now : _end ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 40),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(insurancesRepositoryProvider);
      final provider = _providerCtrl.text.trim();
      final policy = _emptyToNull(_policyCtrl.text);
      final notes = _emptyToNull(_notesCtrl.text);
      if (widget.isEdit) {
        await repo.updateInsurance(
          uuid: widget.insuranceUuid!,
          provider: provider,
          policyNumber: policy,
          contractStart: _start,
          contractEnd: _end,
          notes: notes,
        );
      } else {
        final newUuid = await repo.createInsurance(
          petUuid: widget.petUuid,
          provider: provider,
          policyNumber: policy,
          contractStart: _start,
          contractEnd: _end,
          notes: notes,
        );
        for (final d in _pendingDocs) {
          await repo.attachDocument(
            insuranceUuid: newUuid,
            source: d.file,
            mimeType: d.mimeType,
            originalFilename: d.originalFilename,
            sizeBytes: d.sizeBytes,
          );
        }
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _attachDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) return;
    final mime = _mimeFor(file.extension);
    if (widget.isEdit) {
      await ref.read(insurancesRepositoryProvider).attachDocument(
            insuranceUuid: widget.insuranceUuid!,
            source: File(path),
            mimeType: mime,
            originalFilename: file.name,
            sizeBytes: file.size,
          );
    } else {
      setState(() => _pendingDocs.add(_PendingDoc(
            file: File(path),
            originalFilename: file.name,
            mimeType: mime,
            sizeBytes: file.size,
          )));
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
        .read(insurancesRepositoryProvider)
        .deleteByUuid(widget.insuranceUuid!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final title = widget.isEdit
        ? l.insuranceEditEditTitle
        : l.insuranceEditNewTitle;

    if (widget.isEdit) {
      final async = ref.watch(insuranceByUuidProvider(
        (insuranceUuid: widget.insuranceUuid!, petUuid: widget.petUuid),
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
        data: (ins) {
          if (ins == null) {
            return Scaffold(appBar: AppBar(title: Text(title)));
          }
          _prefill(ins);
          return _buildScaffold(context, title, l, ins);
        },
      );
    }
    return _buildScaffold(context, title, l, null);
  }

  Widget _buildScaffold(
    BuildContext context,
    String title,
    AppL10n l,
    Insurance? insurance,
  ) {
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
              controller: _providerCtrl,
              decoration:
                  InputDecoration(labelText: l.insuranceFieldProvider),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l.validationRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _policyCtrl,
              decoration: InputDecoration(labelText: l.insuranceFieldPolicy),
            ),
            const SizedBox(height: 16),
            _dateField(
              label: l.insuranceFieldContractStart,
              value: _start,
              onTap: () => _pickDate(true),
              onClear: () => setState(() => _start = null),
              locale: locale,
            ),
            const SizedBox(height: 16),
            _dateField(
              label: l.insuranceFieldContractEnd,
              value: _end,
              onTap: () => _pickDate(false),
              onClear: () => setState(() => _end = null),
              locale: locale,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: l.petFieldNotes),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _documentsSection(context, l, insurance),
            const SizedBox(height: 24),
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

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
    required String locale,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value == null ? '—' : DateFormat.yMd(locale).format(value),
        ),
      ),
    );
  }

  Widget _documentsSection(
    BuildContext context,
    AppL10n l,
    Insurance? ins,
  ) {
    final saved = ins?.documents ?? const <InsuranceDocument>[];
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
                      l.insuranceDocumentsSection,
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
            if (saved.isEmpty && _pendingDocs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l.insuranceDocumentsEmpty,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final doc in saved)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  doc.mimeType == 'application/pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                ),
                title: Text(
                  doc.displayName(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: doc.sizeBytes == null
                    ? null
                    : Text(_formatSize(doc.sizeBytes!)),
                onTap: () => _openDoc(context, doc.filePath),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'rename':
                        final result = await showAttachmentRenameDialog(
                          context: context,
                          initialTitle: doc.title,
                          subtitle: doc.originalFilename,
                        );
                        if (result == null) return;
                        await ref
                            .read(insurancesRepositoryProvider)
                            .renameDocument(doc.uuid, result);
                        break;
                      case 'delete':
                        await ref
                            .read(insurancesRepositoryProvider)
                            .removeDocument(doc.uuid);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'rename', child: Text(l.actionRename)),
                    PopupMenuItem(
                        value: 'delete', child: Text(l.actionDelete)),
                  ],
                ),
              ),
            for (var i = 0; i < _pendingDocs.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.hourglass_top_outlined),
                title: Text(
                  _pendingDocs[i].originalFilename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_formatSize(_pendingDocs[i].sizeBytes)),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l.actionClear,
                  onPressed: () =>
                      setState(() => _pendingDocs.removeAt(i)),
                ),
              ),
          ],
        ),
      ),
    );
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
}

class _PendingDoc {
  const _PendingDoc({
    required this.file,
    required this.originalFilename,
    required this.mimeType,
    required this.sizeBytes,
  });

  final File file;
  final String originalFilename;
  final String mimeType;
  final int sizeBytes;
}
