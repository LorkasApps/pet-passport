/// Seam over Supabase Realtime so tests can drive `postgres_changes`
/// deterministically without a live channel. Production wires it to
/// SupabaseRealtimeSource (below); tests wire it to FakeRealtimeSource.
///
/// One subscription per feature table, filtered on household_id, is
/// what the RealtimeEngine uses. Multiplexing them into a single
/// broadcast channel would save one JWT+auth round-trip but obscures
/// the per-table scope; keeping them separate is simpler and matches
/// the shape of `postgres_changes` filtering.
abstract class RealtimeSource {
  RealtimeSubscription subscribeChanges({
    required String table,
    required List<String> householdIds,
    required void Function(RealtimeChange change) onChange,
    void Function()? onDisconnect,
  });
}

/// Handle to one active subscription. The engine keeps a list and
/// calls `dispose` on each when the scope changes (household join /
/// sign-out) or when the app shuts down.
abstract class RealtimeSubscription {
  void dispose();
}

/// A single row-level change delivered by the source. `newRow` is the
/// row after the change (INSERT / UPDATE). `oldRow` is present for
/// UPDATE (previous state) and DELETE. Both are in cloud shape —
/// snake_case columns, ISO-8601 timestamps — just like the return of
/// [CloudApi.fetchChangesSince], so the engine can hand them straight
/// to [PullEngine.applyRow].
class RealtimeChange {
  const RealtimeChange({
    required this.table,
    required this.type,
    this.newRow,
    this.oldRow,
  });

  final String table;
  final RealtimeChangeType type;
  final Map<String, dynamic>? newRow;
  final Map<String, dynamic>? oldRow;
}

enum RealtimeChangeType { insert, update, delete }
