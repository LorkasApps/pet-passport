import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../application/vets_providers.dart';
import '../domain/vet.dart';

class VetEditScreen extends ConsumerStatefulWidget {
  const VetEditScreen({
    super.key,
    required this.petUuid,
    this.vetUuid,
  });

  final String petUuid;
  final String? vetUuid;

  bool get isEdit => vetUuid != null;

  @override
  ConsumerState<VetEditScreen> createState() => _VetEditScreenState();
}

class _VetEditScreenState extends ConsumerState<VetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _practiceCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _prefilled = false;
  bool _saving = false;
  bool _isActive = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _practiceCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _prefill(Vet vet) {
    if (_prefilled) return;
    _prefilled = true;
    _nameCtrl.text = vet.name;
    _practiceCtrl.text = vet.practice ?? '';
    _addressCtrl.text = vet.address ?? '';
    _phoneCtrl.text = vet.phone ?? '';
    _emailCtrl.text = vet.email ?? '';
    _notesCtrl.text = vet.notes ?? '';
    _isActive = vet.isActive;
  }

  String? _emptyToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(vetsRepositoryProvider);
      final name = _nameCtrl.text.trim();
      final practice = _emptyToNull(_practiceCtrl.text);
      final address = _emptyToNull(_addressCtrl.text);
      final phone = _emptyToNull(_phoneCtrl.text);
      final email = _emptyToNull(_emailCtrl.text);
      final notes = _emptyToNull(_notesCtrl.text);

      if (widget.isEdit) {
        await repo.updateVet(
          uuid: widget.vetUuid!,
          name: name,
          practice: practice,
          address: address,
          phone: phone,
          email: email,
          notes: notes,
          isActive: _isActive,
        );
      } else {
        await repo.createVet(
          petUuid: widget.petUuid,
          name: name,
          practice: practice,
          address: address,
          phone: phone,
          email: email,
          notes: notes,
          isActive: _isActive,
        );
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
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
    await ref.read(vetsRepositoryProvider).deleteByUuid(widget.vetUuid!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final title = widget.isEdit ? l.vetEditEditTitle : l.vetEditNewTitle;

    if (widget.isEdit) {
      final async = ref.watch(vetByUuidProvider(
        (vetUuid: widget.vetUuid!, petUuid: widget.petUuid),
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
        data: (vet) {
          if (vet == null) {
            return Scaffold(appBar: AppBar(title: Text(title)));
          }
          _prefill(vet);
          return _buildScaffold(context, title, l);
        },
      );
    }
    return _buildScaffold(context, title, l);
  }

  Widget _buildScaffold(BuildContext context, String title, AppL10n l) {
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
              decoration: InputDecoration(labelText: l.vetFieldName),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l.validationRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _practiceCtrl,
              decoration: InputDecoration(labelText: l.vetFieldPractice),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressCtrl,
              decoration: InputDecoration(labelText: l.vetFieldAddress),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              decoration: InputDecoration(labelText: l.vetFieldPhone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              decoration: InputDecoration(labelText: l.vetFieldEmail),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: l.petFieldNotes),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.vetActiveLabel),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
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
}
