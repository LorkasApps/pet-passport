/// Abstraction over the cloud backend the push worker talks to.
///
/// The push worker only ever calls this interface; production wires it to
/// the Supabase-backed implementation, tests wire it to an in-memory
/// fake. Keeps the retry/backoff/single-flight logic testable without a
/// live Supabase project.
abstract class CloudApi {
  /// Upsert one row on the cloud side. Wholesale-replace semantics — the
  /// caller passes the full post-write payload from the outbox, we don't
  /// try to compute deltas.
  ///
  /// [table] is the physical table name (e.g. `pets`, `pet_documents`).
  /// [uuid] is the primary key on the cloud side; the caller MUST have
  /// already stripped the local Drift `id`.
  /// [payload] is the full row body. Column-name translation
  /// (camelCase → snake_case) is the responsibility of the impl, not
  /// the caller — the outbox is device-local and camelCase.
  Future<CloudUpsertResult> upsertRow({
    required String table,
    required String uuid,
    required Map<String, dynamic> payload,
  });

  /// Delta-pull: fetch rows from [table] that changed after [since],
  /// scoped to [householdIds]. Result rows are in cloud shape
  /// (snake_case columns, ISO-8601 datetimes). The pull engine
  /// translates them back to local shape and applies.
  ///
  /// [since] null = "everything I can see" — used for the very first
  /// pull on a fresh install / after a cursor reset.
  ///
  /// Ordering: ascending `updated_at`. The pull engine advances the
  /// per-table cursor to the max `updated_at` of the returned page.
  /// A [limit] guard bounds a page (default 500) so a very large
  /// household doesn't blow up the response — the pull engine loops
  /// until fewer than [limit] rows come back.
  Future<CloudFetchResult> fetchChangesSince({
    required String table,
    required DateTime? since,
    required List<String> householdIds,
    int limit = 500,
  });
}

/// Outcome of a single upsert attempt. The push worker branches on this
/// to decide whether to delete the op, bump retry, or park it as a
/// terminal failure.
sealed class CloudUpsertResult {
  const CloudUpsertResult();
}

class CloudUpsertOk extends CloudUpsertResult {
  const CloudUpsertOk();
}

/// Transient failure — network glitch, 429, 5xx, Supabase pause resume.
/// Worker keeps the op, bumps `attempts`, waits for the next backoff
/// window.
class CloudUpsertRetryable extends CloudUpsertResult {
  const CloudUpsertRetryable(this.reason);
  final String reason;
}

/// Permanent failure — 4xx that will keep failing on retry (schema
/// mismatch, RLS deny, unknown column). Worker parks the op with the
/// error message so the user (or a support flow) can inspect it via
/// the debug pane. Never auto-retries.
class CloudUpsertTerminal extends CloudUpsertResult {
  const CloudUpsertTerminal(this.reason);
  final String reason;
}

/// One page of pulled rows plus a hint about whether more might be
/// waiting behind them. The pull engine calls fetchChangesSince in a
/// loop until [maybeMore] is false.
class CloudFetchResult {
  const CloudFetchResult({
    required this.rows,
    required this.maybeMore,
  });

  final List<Map<String, dynamic>> rows;
  final bool maybeMore;
}
