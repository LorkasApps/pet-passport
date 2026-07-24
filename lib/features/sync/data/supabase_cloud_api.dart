import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_api.dart';

/// Real [CloudApi] backed by Supabase. Owns two responsibilities:
///   1. Translate the local outbox payload shape (camelCase keys, ints
///      for datetimes) into the cloud table shape (snake_case columns,
///      ISO-8601 timestamps).
///   2. Turn the SDK's exception zoo into a [CloudUpsertResult] the
///      push worker can branch on without knowing anything about
///      Supabase internals.
///
/// The upsert uses `Prefer: return=minimal` (no `.select()` chained on)
/// so a successful push is a single round-trip. We don't need the
/// returned row — the local copy is already authoritative.
class SupabaseCloudApi implements CloudApi {
  SupabaseCloudApi({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<CloudUpsertResult> upsertRow({
    required String table,
    required String uuid,
    required Map<String, dynamic> payload,
  }) async {
    final body = toCloudShape(payload);
    try {
      await _client.from(table).upsert(body);
      return const CloudUpsertOk();
    } on PostgrestException catch (e) {
      return _classifyPostgrest(e);
    } on AuthException catch (e) {
      // Session state issue — session refresh will fix it on the next
      // drain. Not terminal.
      return CloudUpsertRetryable('auth: ${e.message}');
    } on SocketException catch (e) {
      return CloudUpsertRetryable('socket: ${e.message}');
    } on TimeoutException catch (_) {
      return const CloudUpsertRetryable('timeout');
    } catch (e) {
      // Anything unclassified — retryable so a bad diagnosis doesn't
      // strand a legitimate op forever.
      return CloudUpsertRetryable('unknown: $e');
    }
  }

  CloudUpsertResult _classifyPostgrest(PostgrestException e) {
    // PostgrestException exposes `code` (Postgres SQLSTATE) and, on
    // newer versions, `statusCode` (HTTP). Use whichever is present.
    final http = int.tryParse(e.code ?? '') ?? _statusOf(e);
    final msg = e.message;
    if (http == 429 || (http >= 500 && http < 600)) {
      return CloudUpsertRetryable('http $http: $msg');
    }
    if (http == 401) {
      // Session ran out mid-flight; a refresh (or re-login) recovers.
      return CloudUpsertRetryable('http 401: $msg');
    }
    // 400 / 403 / 404 / 409 / 422 → contract / permission / schema
    // mismatch. Retrying won't help.
    return CloudUpsertTerminal('http $http: $msg');
  }

  /// Best-effort HTTP status recovery — supabase_flutter versions differ
  /// on how they expose it. Falls back to 500 (retryable) so an unknown
  /// error doesn't get accidentally parked as terminal.
  int _statusOf(PostgrestException e) {
    final dyn = e as dynamic;
    try {
      final s = dyn.statusCode;
      if (s is int) return s;
      if (s is String) return int.tryParse(s) ?? 500;
    } catch (_) {}
    return 500;
  }

  @override
  Future<CloudFetchResult> fetchChangesSince({
    required String table,
    required DateTime? since,
    required List<String> householdIds,
    int limit = 500,
  }) async {
    // Empty household list ⇒ RLS would drop everything anyway; skip
    // the round-trip.
    if (householdIds.isEmpty) {
      return const CloudFetchResult(rows: [], maybeMore: false);
    }
    // PostgREST returns a wide-open resource; we page with
    // limit(limit+1) so we can tell "more" from "exact fit" without a
    // second call.
    var q = _client.from(table).select().inFilter('household_id', householdIds);
    if (since != null) {
      q = q.gt('updated_at', since.toUtc().toIso8601String());
    }
    final res = await q
        .order('updated_at', ascending: true)
        .limit(limit + 1);
    final rows =
        (res as List).cast<Map<String, dynamic>>().toList(growable: false);
    final maybeMore = rows.length > limit;
    return CloudFetchResult(
      rows: maybeMore ? rows.take(limit).toList(growable: false) : rows,
      maybeMore: maybeMore,
    );
  }
}

/// Every DateTime-shaped column across the top-level tables. Drift's
/// default serializer emits DateTime as an int (millisSinceEpoch); the
/// cloud columns are `timestamptz`, and PostgREST won't implicitly
/// cast a bigint into one — a missing entry here silently ships as
/// int and comes back as a terminal 4xx.
///
/// The set is intentionally the union of every top-level table's
/// datetime columns rather than per-table, since the translator runs
/// per-payload without knowing which table it belongs to. A stray key
/// that never appears on a given row is harmless.
const _dateTimeKeys = <String>{
  // Every table
  'createdAt',
  'updatedAt',
  'deletedAt',
  // pets
  'dateOfBirth',
  'tassoRegisteredAt',
  // events
  'occurredAt',
  // pet_weights (not synced yet but harmless to list)
  'measuredAt',
  // appointments
  'startsAt',
  'recurrenceUntil',
  // medications + foods
  'endsAt',
  // (starts_at shared with appointments already covered above)
  // vaccinations
  'administeredAt',
  'nextDueAt',
  // insurances
  'contractStart',
  'contractEnd',
  // pending_ops — device-local, never pushed. Left here so the
  // translator stays defensive if a stray payload ever includes them.
  'lastAttemptAt',
  'queuedAt',
};

/// Semantic key renames applied before the camelCase → snake_case
/// pass. Client Drift row.toJson emits `uuid`, but the cloud schema
/// (migration 0004) uses Postgres-idiomatic `id uuid PK` — pure
/// camel→snake wouldn't catch that.
const _semanticRenames = <String, String>{
  'uuid': 'id',
};

/// Pure payload translator. Kept top-level so tests can exercise it
/// without spinning up a SupabaseClient.
///
/// Turns the outbox payload into a body PostgREST can accept:
///   * semantic renames first: `uuid` → `id` (cloud PK name)
///   * then key names: camelCase → snake_case (`updatedAt` → `updated_at`)
///   * datetimes: int millis → ISO-8601 (`.toUtc().toIso8601String()`)
///
/// The datetime-key list is deliberately hand-maintained instead of
/// heuristically sniffing "looks like millis" — that heuristic would
/// misfire on a stray int column (e.g. `sizeBytes`).
Map<String, dynamic> toCloudShape(Map<String, dynamic> payload) {
  final out = <String, dynamic>{};
  payload.forEach((k, v) {
    final key = camelToSnake(_semanticRenames[k] ?? k);
    if (v == null) {
      out[key] = null;
      return;
    }
    if (_dateTimeKeys.contains(k) && v is int) {
      out[key] = DateTime.fromMillisecondsSinceEpoch(v, isUtc: true)
          .toIso8601String();
      return;
    }
    out[key] = v;
  });
  return out;
}

String camelToSnake(String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    final upper = ch.toUpperCase();
    final isUpper = ch == upper && ch != ch.toLowerCase();
    if (isUpper && i > 0) buf.write('_');
    buf.write(ch.toLowerCase());
  }
  return buf.toString();
}

/// Reverse of [_semanticRenames] for pull-side use.
const _semanticRenamesReverse = <String, String>{
  'id': 'uuid',
};

/// Pure translator, cloud shape → local Drift shape. Reverse of
/// [toCloudShape]:
///   * `id` → `uuid` (Postgres PK naming → Drift's column name)
///   * snake_case → camelCase (`updated_at` → `updatedAt`)
///   * ISO-8601 datetime keys → int millisSinceEpoch (what Drift's
///     default value serializer emits, so round-trips are lossless)
///
/// The datetime-column list is derived from [_dateTimeKeys] — a key
/// that's a datetime one way is a datetime the other way. Since the
/// cloud-side keys are snake_case we snake-transform the reference
/// set once at module scope.
final _dateTimeKeysSnake = <String>{
  for (final k in _dateTimeKeys) camelToSnake(k),
};

Map<String, dynamic> fromCloudShape(Map<String, dynamic> payload) {
  final out = <String, dynamic>{};
  payload.forEach((k, v) {
    // Semantic rename first (id → uuid), then reverse-snake.
    final camelKey =
        snakeToCamel(_semanticRenamesReverse[k] ?? k);
    if (v == null) {
      out[camelKey] = null;
      return;
    }
    if (_dateTimeKeysSnake.contains(k) && v is String) {
      out[camelKey] =
          DateTime.parse(v).millisecondsSinceEpoch;
      return;
    }
    out[camelKey] = v;
  });
  return out;
}

String snakeToCamel(String s) {
  final buf = StringBuffer();
  var upperNext = false;
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == '_') {
      upperNext = true;
      continue;
    }
    if (upperNext) {
      buf.write(ch.toUpperCase());
      upperNext = false;
    } else {
      buf.write(ch);
    }
  }
  return buf.toString();
}
