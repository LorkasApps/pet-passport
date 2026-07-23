import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../auth/application/auth_providers.dart';
import '../application/households_providers.dart';
import '../data/invite_repository.dart';
import 'qr_scan_screen.dart';

/// Unified entry point for joining a household via invite code. Handles
/// three arrival paths equally:
///   1. Deep link `petpassport://invite/<token>` — router normalises to
///      `/join?token=<token>` and this screen mounts with the field
///      prefilled.
///   2. QR scanner button on this screen — pops back with the token
///      and we fill the field.
///   3. Manual paste / type — user enters the token themselves.
///
/// Requires the caller to already be signed in. If not, we route them
/// to sign-in with a hint; they can come back and paste the same code
/// afterwards (invite tokens are TTL-bound but valid across sign-in).
class JoinHouseholdScreen extends ConsumerStatefulWidget {
  const JoinHouseholdScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<JoinHouseholdScreen> createState() =>
      _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends ConsumerState<JoinHouseholdScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) {
      _ctrl.text = widget.initialToken!;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final token = await context.push<String?>('/join/scan');
    if (token != null && mounted) {
      setState(() => _ctrl.text = token);
    }
  }

  Future<void> _join() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(inviteRepositoryProvider).redeem(raw);
      // Force the household list to include the new membership.
      ref.invalidate(myHouseholdsProvider);
      if (!mounted) return;
      await _showSuccess(result);
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _prettyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSuccess(InviteRedemptionResult r) async {
    final l = AppL10n.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.joinSuccessTitle),
        content: Text(l.joinSuccessBody(r.householdName, r.memberCount)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.actionConfirm),
          ),
        ],
      ),
    );
  }

  String _prettyError(Object e) {
    final s = e.toString();
    // The Postgres RPC raises these strings verbatim; catch them for a
    // more user-facing message and fall back to the raw error otherwise.
    if (s.contains('invalid invite')) return AppL10n.of(context).joinErrorInvalid;
    if (s.contains('invite expired')) return AppL10n.of(context).joinErrorExpired;
    if (s.contains('invite already used')) return AppL10n.of(context).joinErrorUsed;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final signedIn = ref.watch(isSignedInProvider);
    if (!signedIn) return _buildNeedsSignIn(l);
    return Scaffold(
      appBar: AppBar(title: Text(l.joinScreenTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.joinHeadline,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l.joinBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _ctrl,
              autofocus: widget.initialToken == null,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l.joinCodeLabel,
                hintText: 'X4KM-9RTW',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l.joinScanAction),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _join,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(l.joinAction),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNeedsSignIn(AppL10n l) {
    return Scaffold(
      appBar: AppBar(title: Text(l.joinScreenTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(l.joinNeedSignInHeadline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l.joinNeedSignInBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/auth/signin'),
              child: Text(l.settingsSignIn),
            ),
          ],
        ),
      ),
    );
  }
}

