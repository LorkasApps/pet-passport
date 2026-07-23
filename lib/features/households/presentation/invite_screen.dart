import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../application/households_providers.dart';
import '../domain/invite_code.dart';

/// Owner-only screen: generates and shows a household invite (QR + text
/// code + shareable deep link) with a live countdown. Reuses an active
/// unexpired code if one exists so refreshing this screen doesn't spam
/// invite_codes rows.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  Timer? _tick;
  DateTime _now = DateTime.now();
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    // 1 Hz refresh for the countdown label. Doesn't hit the DB.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      await ref
          .read(householdInvitesProvider(widget.householdId).notifier)
          .generate();
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _revoke(InviteCode code) async {
    await ref
        .read(householdInvitesProvider(widget.householdId).notifier)
        .revoke(code.id);
  }

  Future<void> _copy(String text, AppL10n l) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.copiedToClipboard)),
    );
  }

  Future<void> _share(InviteCode code, AppL10n l) async {
    await Share.share(
      l.inviteShareBody(code.deepLink),
      subject: l.inviteShareSubject,
    );
  }

  String _fmtCountdown(Duration d, AppL10n l) {
    if (d.isNegative) return l.inviteExpired;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return l.inviteExpiresInHours(h, m);
    if (m > 0) return l.inviteExpiresInMinutes(m, s);
    return l.inviteExpiresInSeconds(s);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final async = ref.watch(householdInvitesProvider(widget.householdId));

    return Scaffold(
      appBar: AppBar(title: Text(l.inviteScreenTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (codes) {
          if (codes.isEmpty) return _buildEmpty(l);
          // Pick the newest active code; extras (rare — usually from
          // parallel taps) get their own tiles below for revoke.
          final primary = codes.first;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(l.inviteHeadline,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                l.inviteBody,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: primary.deepLink,
                    size: 220,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: SelectableText(
                  _formatTokenForDisplay(primary.token),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 4,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _fmtCountdown(primary.expiresAt.difference(_now), l),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copy(primary.deepLink, l),
                      icon: const Icon(Icons.copy),
                      label: Text(l.inviteCopyLink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _share(primary, l),
                      icon: const Icon(Icons.share),
                      label: Text(l.inviteShareLink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.refresh),
                label: Text(l.inviteRegenerate),
              ),
              TextButton.icon(
                onPressed: () => _revoke(primary),
                icon: const Icon(Icons.block),
                label: Text(l.inviteRevoke),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty(AppL10n l) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_outlined,
              size: 96, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(l.inviteEmptyHeadline,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            l.inviteEmptyBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(l.inviteGenerate),
          ),
        ],
      ),
    );
  }

  /// 'X4KM9RTW' → 'X4KM-9RTW' for easier eyeball / manual typing.
  String _formatTokenForDisplay(String token) {
    if (token.length != 8) return token;
    return '${token.substring(0, 4)}-${token.substring(4)}';
  }
}
