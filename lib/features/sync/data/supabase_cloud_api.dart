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
}

const _dateTimeKeys = <String>{
  'createdAt',
  'updatedAt',
  'deletedAt',
  'occurredAt',
  'dateOfBirth',
  'tassoRegisteredAt',
  'measuredAt',
  'lastAttemptAt',
  'queuedAt',
};

/// Pure payload translator. Kept top-level so tests can exercise it
/// without spinning up a SupabaseClient.
///
/// Turns the outbox payload into a body PostgREST can accept:
///   * key names: camelCase → snake_case (`updatedAt` → `updated_at`)
///   * datetimes: int millis → ISO-8601 (`.toUtc().toIso8601String()`)
///
/// The datetime-key list is deliberately hand-maintained instead of
/// heuristically sniffing "looks like millis" — that heuristic would
/// misfire on a stray int column (e.g. `sizeBytes`).
Map<String, dynamic> toCloudShape(Map<String, dynamic> payload) {
  final out = <String, dynamic>{};
  payload.forEach((k, v) {
    final key = camelToSnake(k);
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
