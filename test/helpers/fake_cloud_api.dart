import 'package:pet_passport/features/sync/data/cloud_api.dart';
import 'package:pet_passport/features/sync/data/supabase_cloud_api.dart'
    show toCloudShape;

/// In-memory [CloudApi] double for sync tests.
///
/// - Stores rows keyed by (table, uuid) so tests can assert on cloud state
///   directly.
/// - Assigns a monotonic `pulled_seq` on every upsert / seed to mimic the
///   server-side bigserial that migration 0011 puts on every synced table.
/// - Applies LWW on `updated_at` so tests can drive conflict scenarios:
///   a stale payload silently loses without a retryable error.
/// - Programmable failure modes via [queueRetryable] and [queueTerminal]
///   for driving the worker down its non-happy paths.
class FakeCloudApi implements CloudApi {
  final Map<String, Map<String, Map<String, dynamic>>> rows = {};
  final List<FakeUpsertCall> calls = [];
  final List<CloudUpsertResult> _forced = [];
  int _seq = 0;

  /// Force the next N calls to return the given result, in order. Runs
  /// out → we fall back to the normal LWW-store behaviour.
  void queueResult(CloudUpsertResult r) => _forced.add(r);
  void queueRetryable([String reason = 'fake retryable']) =>
      _forced.add(CloudUpsertRetryable(reason));
  void queueTerminal([String reason = 'fake terminal']) =>
      _forced.add(CloudUpsertTerminal(reason));

  @override
  Future<CloudUpsertResult> upsertRow({
    required String table,
    required String uuid,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(FakeUpsertCall(table, uuid, Map.of(payload)));
    if (_forced.isNotEmpty) {
      return _forced.removeAt(0);
    }
    // Store rows in cloud wire shape so fetchChangesSince returns
    // exactly what the real PostgREST would — snake_case columns,
    // ISO-8601 datetimes, `id` PK. This mirrors what
    // SupabaseCloudApi does on the wire.
    final body = toCloudShape(payload);
    final store = rows.putIfAbsent(table, () => {});
    final existing = store[uuid];
    if (existing != null) {
      // LWW on `updated_at` — ISO strings compare lexicographically
      // in chronological order.
      final incoming = body['updated_at'] as String?;
      final current = existing['updated_at'] as String?;
      if (incoming != null &&
          current != null &&
          incoming.compareTo(current) < 0) {
        return const CloudUpsertOk(); // silent loser, don't overwrite
      }
    }
    // Server-side sequence: every write bumps pulled_seq. Real
    // Supabase uses a trigger + nextval; here it's a counter.
    body['pulled_seq'] = ++_seq;
    store[uuid] = body;
    return const CloudUpsertOk();
  }

  Map<String, dynamic>? find(String table, String uuid) =>
      rows[table]?[uuid];

  /// Direct-seed a row for pull tests — bypasses upsert so tests can
  /// stand up a remote-side state without going through the outbox
  /// machinery first. Auto-assigns a fresh pulled_seq unless the row
  /// already has one.
  void seed(String table, Map<String, dynamic> row) {
    final copy = Map<String, dynamic>.from(row);
    copy['pulled_seq'] ??= ++_seq;
    final id = copy['id'] as String;
    rows.putIfAbsent(table, () => {})[id] = copy;
  }

  @override
  Future<CloudFetchResult> fetchChangesSince({
    required String table,
    required int? sinceSeq,
    required List<String> householdIds,
    int limit = 500,
  }) async {
    final store = rows[table] ?? const {};
    final cutoff = sinceSeq ?? 0;
    final matched = <Map<String, dynamic>>[];
    for (final row in store.values) {
      final hid = row['household_id'] as String?;
      if (hid == null || !householdIds.contains(hid)) continue;
      final seq = row['pulled_seq'] as int? ?? 0;
      if (seq <= cutoff) continue;
      matched.add(Map.of(row));
    }
    matched.sort((a, b) {
      final sa = a['pulled_seq'] as int? ?? 0;
      final sb = b['pulled_seq'] as int? ?? 0;
      return sa.compareTo(sb);
    });
    final page = matched.take(limit).toList(growable: false);
    return CloudFetchResult(
      rows: page,
      maybeMore: matched.length > limit,
    );
  }
}

class FakeUpsertCall {
  FakeUpsertCall(this.table, this.uuid, this.payload);
  final String table;
  final String uuid;
  final Map<String, dynamic> payload;
}
