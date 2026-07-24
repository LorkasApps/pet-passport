import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../settings/application/settings_providers.dart';
import '../data/cloud_api.dart';
import '../data/pull_engine.dart';
import '../data/push_worker.dart';
import '../data/supabase_cloud_api.dart';
import '../data/sync_outbox.dart';

final syncOutboxProvider = Provider<SyncOutbox>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncOutbox(db);
});

/// The concrete cloud endpoint the push worker talks to. `null` in
/// pure-local mode — every downstream provider guards on this.
final cloudApiProvider = Provider<CloudApi?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  return SupabaseCloudApi();
});

/// The push worker. `null` if cloud isn't configured — the outbox
/// still accepts writes, they just stay parked locally.
final pushWorkerProvider = Provider<PushWorker?>((ref) {
  final api = ref.watch(cloudApiProvider);
  if (api == null) return null;
  final db = ref.watch(databaseProvider);
  return PushWorker(db.pendingOpsDao, api);
});

/// Live count of ops sitting in `pending_ops`. Drives the sync-status
/// UI and, via the app-level `ref.listenManual` hook, wakes the push
/// worker whenever a new write enqueues something.
final pendingOpsCountProvider = StreamProvider<int>((ref) {
  final outbox = ref.watch(syncOutboxProvider);
  return outbox.watchPendingCount();
});

/// The delta-pull engine. `null` if cloud isn't configured — mirrors
/// the pushWorkerProvider guard.
final pullEngineProvider = Provider<PullEngine?>((ref) {
  final api = ref.watch(cloudApiProvider);
  if (api == null) return null;
  final db = ref.watch(databaseProvider);
  return PullEngine(db, api);
});
