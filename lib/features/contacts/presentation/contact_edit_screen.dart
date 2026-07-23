import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../application/contacts_providers.dart';
import '../domain/contact.dart';
import '../domain/contact_enums.dart';
import 'contacts_list_screen.dart' show contactRoleLabel;

class ContactEditScreen extends ConsumerStatefulWidget {
  const ContactEditScreen({
    super.key,
    required this.petUuid,
    this.contactUuid,
  });

  final String petUuid;
  final String? contactUuid;

  bool get isEdit => contactUuid != null;

  @override
  ConsumerState<ContactEditScreen> createState() =>
      _ContactEditScreenState();
}

class _ContactEditScreenState extends ConsumerState<ContactEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  ContactRole _role = ContactRole.sitter;
  bool _isActive = true;
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _orgCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _prefill(Contact c) {
    if (_prefilled) return;
    _prefilled = true;
    _nameCtrl.text = c.name;
    _orgCtrl.text = c.organization ?? '';
    _addressCtrl.text = c.address ?? '';
    _phoneCtrl.text = c.phone ?? '';
    _emailCtrl.text = c.email ?? '';
    _notesCtrl.text = c.notes ?? '';
    _role = c.role;
    _isActive = c.isActive;
  }

  String? _emptyToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(contactsRepositoryProvider);
      final name = _nameCtrl.text.trim();
      final org = _emptyToNull(_orgCtrl.text);
      final address = _emptyToNull(_addressCtrl.text);
      final phone = _emptyToNull(_phoneCtrl.text);
      final email = _emptyToNull(_emailCtrl.text);
      final notes = _emptyToNull(_notesCtrl.text);
      if (widget.isEdit) {
        await repo.updateContact(
          uuid: widget.contactUuid!,
          name: name,
          role: _role,
          organization: org,
          address: address,
          phone: phone,
          email: email,
          notes: notes,
          isActive: _isActive,
        );
      } else {
        await repo.createContact(
          petUuid: widget.petUuid,
          name: name,
          role: _role,
          organization: org,
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
    if (ok != true || !mounted) return;
    await ref
        .read(contactsRepositoryProvider)
        .deleteByUuid(widget.contactUuid!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final title =
        widget.isEdit ? l.contactEditEditTitle : l.contactEditNewTitle;

    if (widget.isEdit) {
      final async = ref.watch(contactByUuidProvider(
        (contactUuid: widget.contactUuid!, petUuid: widget.petUuid),
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
        data: (c) {
          if (c == null) return Scaffold(appBar: AppBar(title: Text(title)));
          _prefill(c);
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
              decoration: InputDecoration(labelText: l.contactFieldName),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l.validationRequired
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ContactRole>(
              initialValue: _role,
              decoration: InputDecoration(labelText: l.contactFieldRole),
              items: [
                for (final r in ContactRole.values)
                  DropdownMenuItem(
                    value: r,
                    child: Text(contactRoleLabel(l, r)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _role = v);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _orgCtrl,
              decoration:
                  InputDecoration(labelText: l.contactFieldOrganization),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressCtrl,
              decoration: InputDecoration(labelText: l.contactFieldAddress),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              decoration: InputDecoration(labelText: l.contactFieldPhone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              decoration: InputDecoration(labelText: l.contactFieldEmail),
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
              title: Text(l.contactActiveLabel),
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
