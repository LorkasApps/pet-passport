import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../auth/application/auth_providers.dart';
import '../application/households_providers.dart';
import '../domain/household.dart';
import '../domain/household_member.dart';

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

  Future<void> _confirmLeave(
    AppL10n l, {
    required bool isOwner,
    required int memberCount,
  }) async {
    // Sole-owner guardrail: can't leave without either transferring
    // ownership (out-of-scope for M1) or deleting the household.
    if (isOwner && memberCount == 1) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.householdLeaveSoloOwnerTitle),
          content: Text(l.householdLeaveSoloOwnerBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.actionCancel),
            ),
          ],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.householdLeaveConfirmTitle),
        content: Text(l.householdLeaveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.householdLeaveAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref
        .read(householdMembersProvider(widget.householdId).notifier)
        .leave();
    if (mounted) context.pop();
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
              const SizedBox(height: 24),
              Text(l.householdMembersHeader,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _MembersList(
                householdId: h.id,
                isOwner: isOwner,
              ),
              if (isOwner) ...[
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      context.push('/households/${h.id}/invite'),
                  icon: const Icon(Icons.person_add_outlined),
                  label: Text(l.householdInvitePerson),
                ),
              ],
              const Divider(height: 48),
              OutlinedButton.icon(
                onPressed: () => _confirmLeave(l, isOwner: isOwner,
                    memberCount: h.memberCount),
                icon: const Icon(Icons.logout),
                label: Text(l.householdLeaveAction),
              ),
              if (isOwner) ...[
                const SizedBox(height: 12),
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

class _MembersList extends ConsumerWidget {
  const _MembersList({required this.householdId, required this.isOwner});

  final String householdId;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final myUserId = ref.watch(currentUserProvider)?.id;
    final async = ref.watch(householdMembersProvider(householdId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('$e'),
      data: (members) {
        if (members.isEmpty) return Text(l.householdMembersEmpty);
        return Column(
          children: [
            for (final m in members)
              _MemberTile(
                householdId: householdId,
                member: m,
                isMe: m.userId == myUserId,
                canRemove: isOwner && m.userId != myUserId,
              ),
          ],
        );
      },
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.householdId,
    required this.member,
    required this.isMe,
    required this.canRemove,
  });

  final String householdId;
  final HouseholdMember member;
  final bool isMe;
  final bool canRemove;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final l = AppL10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.householdMemberRemoveConfirmTitle),
        content: Text(l.householdMemberRemoveConfirmBody(member.displayName)),
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
    await ref
        .read(householdMembersProvider(householdId).notifier)
        .removeMember(member.userId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(
          member.isOwner
              ? Icons.workspace_premium
              : Icons.person_outline,
          color: scheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        isMe
            ? l.householdMemberSelfSuffix(member.displayName)
            : member.displayName,
      ),
      subtitle: Text(member.isOwner
          ? l.householdsRoleOwner
          : l.householdsRoleMember),
      trailing: canRemove
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: l.householdMemberRemoveAction,
              onPressed: () => _confirmRemove(context, ref),
            )
          : null,
    );
  }
}
