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
