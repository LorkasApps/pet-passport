import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../application/households_providers.dart';
import '../domain/household.dart';

class HouseholdDetailScreen extends ConsumerStatefulWidget {
  const HouseholdDetailScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<HouseholdDetailScreen> createState() =>
      _HouseholdDetailScreenState();
}

class _HouseholdDetailScreenState
    extends ConsumerState<HouseholdDetailScreen> {
  final _nameCtrl = TextEditingController();
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _prefill(Household h) {
    if (_prefilled) return;
    _prefilled = true;
    _nameCtrl.text = h.name;
  }

  Future<void> _rename() async {
    final trimmed = _nameCtrl.text.trim();
    if (trimmed.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(myHouseholdsProvider.notifier)
          .rename(widget.householdId, trimmed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(AppL10n l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.householdDeleteConfirmTitle),
        content: Text(l.householdDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref
        .read(myHouseholdsProvider.notifier)
        .delete(widget.householdId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final async = ref.watch(myHouseholdsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.householdDetailTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final h = list.firstWhere(
            (h) => h.id == widget.householdId,
            orElse: () => throw StateError('household gone'),
          );
          _prefill(h);
          final isOwner = h.isOwner;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: _nameCtrl,
                readOnly: !isOwner,
                decoration: InputDecoration(
                  labelText: l.householdFieldName,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => isOwner ? _rename() : null,
              ),
              if (isOwner) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _rename,
                    icon: const Icon(Icons.check),
                    label: Text(l.actionSave),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(isOwner
                    ? l.householdsRoleOwner
                    : l.householdsRoleMember),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.group_outlined),
                title: Text(l.householdsMemberCount(h.memberCount)),
              ),
              if (isOwner) ...[
                const Divider(height: 48),
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(l),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l.householdDeleteAction),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
