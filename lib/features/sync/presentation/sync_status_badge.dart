import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../application/sync_providers.dart';

/// Small AppBar action showing the current cloud-sync state. Icon +
/// tooltip only — the detailed error message lives one tap away in
/// Settings → Cloud sync so the badge stays cheap on all screens.
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final status = ref.watch(syncStatusProvider);
    final scheme = Theme.of(context).colorScheme;

    // Hide entirely when the app was built without cloud config —
    // no reason to nag pure-local users with an icon.
    if (status == SyncStatus.localOnly) return const SizedBox.shrink();

    final (icon, color, tip) = switch (status) {
      SyncStatus.signedOut => (
        Icons.cloud_off_outlined,
        scheme.onSurfaceVariant,
        l.syncBadgeSignedOut,
      ),
      SyncStatus.offline => (
        Icons.cloud_off_outlined,
        scheme.onSurfaceVariant,
        l.syncBadgeOffline,
      ),
      SyncStatus.syncing => (
        Icons.cloud_upload_outlined,
        scheme.primary,
        l.syncBadgeSyncing,
      ),
      SyncStatus.error => (
        Icons.cloud_off_outlined,
        scheme.error,
        l.syncBadgeError,
      ),
      SyncStatus.synced => (
        Icons.cloud_done_outlined,
        scheme.onSurfaceVariant,
        l.syncBadgeSynced,
      ),
      // Handled above; the exhaustive switch just needs a branch.
      SyncStatus.localOnly => (
        Icons.cloud_off_outlined,
        scheme.onSurfaceVariant,
        '',
      ),
    };

    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tip,
      onPressed: () => context.push('/more/settings'),
    );
  }
}
