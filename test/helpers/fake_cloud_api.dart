import 'package:pet_passport/features/sync/data/cloud_api.dart';

/// In-memory [CloudApi] double for push-worker tests.
///
/// - Stores rows keyed by (table, uuid) so tests can assert on cloud state
///   directly.
/// - Applies LWW on `updatedAt` so tests can drive conflict scenarios:
///   a stale payload silently loses without a retryable error.
/// - Programmable failure modes via [queueRetryable] and [queueTerminal]
///   for driving the worker down its non-happy paths.
class FakeCloudApi implements CloudApi {
  final Map<String, Map<String, Map<String, dynamic>>> rows = {};
  final List<FakeUpsertCall> calls = [];
  final List<CloudUpsertResult> _forced = [];

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
    final store = rows.putIfAbsent(table, () => {});
    final existing = store[uuid];
    if (existing != null) {
      // LWW: whichever payload has the larger `updatedAt` wins. Payload
      // shape mirrors the local outbox (camelCase, ISO-8601 strings).
      final incoming = payload['updatedAt'] as String?;
      final current = existing['updatedAt'] as String?;
      if (incoming != null &&
          current != null &&
          incoming.compareTo(current) < 0) {
        return const CloudUpsertOk(); // silent loser, don't overwrite
      }
    }
    store[uuid] = Map.of(payload);
    return const CloudUpsertOk();
  }

  Map<String, dynamic>? find(String table, String uuid) =>
      rows[table]?[uuid];
}

class FakeUpsertCall {
  FakeUpsertCall(this.table, this.uuid, this.payload);
  final String table;
  final String uuid;
  final Map<String, dynamic> payload;
}
