import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../auth/application/auth_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../data/cloud_api.dart';
import '../data/media_outbox.dart';
import '../data/pull_engine.dart';
import '../data/push_worker.dart';
import '../data/realtime_engine.dart';
import '../data/realtime_source.dart';
import '../data/supabase_cloud_api.dart';
import '../data/supabase_realtime_source.dart';
import '../data/sync_outbox.dart';

final syncOutboxProvider = Provider<SyncOutbox>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncOutbox(db);
});

/// Parallel outbox for binary media (uploads to Supabase Storage).
/// Always non-null — the enqueue calls guard on cloud-configured +
/// household-set at the repo level, so a pure-local install just
/// never enqueues.
final mediaOutboxProvider = Provider<MediaOutbox>((ref) {
  final db = ref.watch(databaseProvider);
  return MediaOutbox(db);
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

/// Realtime source seam — real Supabase channel when cloud is
/// configured, null otherwise. Kept as a provider so tests can
/// override with a FakeRealtimeSource.
final realtimeSourceProvider = Provider<RealtimeSource?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  return SupabaseRealtimeSource();
});

/// Long-lived RealtimeEngine. `null` in pure-local mode. The engine
/// keeps its own subscription list; the app-level trigger calls
/// start(...) whenever the household set resolves.
final realtimeEngineProvider = Provider<RealtimeEngine?>((ref) {
  final source = ref.watch(realtimeSourceProvider);
  final pull = ref.watch(pullEngineProvider);
  if (source == null || pull == null) return null;
  final engine = RealtimeEngine(source, pull);
  ref.onDispose(engine.dispose);
  return engine;
});

/// Live realtime connection state stream. `idle` in pure-local mode.
final realtimeStatusProvider = StreamProvider<RealtimeStatus>((ref) {
  final engine = ref.watch(realtimeEngineProvider);
  if (engine == null) return Stream.value(RealtimeStatus.idle);
  return engine.status;
});

/// Most recent lastError from pending_ops. Used by the AppBar
/// indicator + Settings sync tile to surface a hint when the outbox
/// is stuck.
final pendingOpsLastErrorProvider = StreamProvider<String?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.pendingOpsDao.watchLastError();
});

/// High-level sync state the AppBar indicator binds to. Aggregates:
/// - cloud configured?
/// - signed in?
/// - realtime status
/// - pending count > 0?
/// - any last error?
final syncStatusProvider = Provider<SyncStatus>((ref) {
  if (!SupabaseConfig.isConfigured) return SyncStatus.localOnly;
  if (!ref.watch(isSignedInProvider)) return SyncStatus.signedOut;
  final pending = ref.watch(pendingOpsCountProvider).valueOrNull ?? 0;
  final err = ref.watch(pendingOpsLastErrorProvider).valueOrNull;
  final rt = ref.watch(realtimeStatusProvider).valueOrNull ??
      RealtimeStatus.idle;
  if (err != null && pending > 0) return SyncStatus.error;
  if (pending > 0) return SyncStatus.syncing;
  if (rt == RealtimeStatus.disconnected) return SyncStatus.offline;
  return SyncStatus.synced;
});

/// Coarse-grained state for the AppBar cloud indicator.
enum SyncStatus {
  /// Cloud not compiled in — no indicator shown.
  localOnly,

  /// Cloud is on but the user hasn't signed in.
  signedOut,

  /// Realtime channel disconnected (or hasn't come up yet) and
  /// nothing is pending — we'll catch up on the next pull.
  offline,

  /// Outbox draining right now.
  syncing,

  /// Something in the outbox parked with a non-null last_error.
  error,

  /// Everything's up. Green check.
  synced,
}
