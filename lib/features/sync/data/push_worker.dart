import 'dart:convert';

import '../../../core/db/daos/pending_ops_dao.dart';
import '../../../core/db/database.dart';
import 'cloud_api.dart';

/// Drains the local outbox (`pending_ops`) FIFO into the cloud via
/// [CloudApi]. Deliberately dumb: reads a head window, tries each row,
/// deletes on success, bumps + parks on failure. The scheduler that
/// decides *when* to call [drainOnce] (network return, app foreground,
/// after-write trigger) is a layer above.
///
/// Single-flight: overlapping drains are collapsed. A caller that fires
/// [drainOnce] while a previous one is still running gets the same
/// future back. Prevents a rapid burst of writes from spawning parallel
/// drains that would race on the same op ids.
class PushWorker {
  PushWorker(this._dao, this._cloud, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final PendingOpsDao _dao;
  final CloudApi _cloud;
  final DateTime Function() _now;

  /// Backoff schedule keyed by prior-attempt count.
  ///   0 attempts (never tried)  → eligible immediately
  ///   1                         → wait 500 ms
  ///   2                         → 2 s
  ///   3                         → 8 s
  ///   4                         → 30 s
  ///   5+                        → idle (only manual retry or next
  ///                               drainOnce trigger will pick it up)
  static const _backoffs = <Duration>[
    Duration.zero,
    Duration(milliseconds: 500),
    Duration(seconds: 2),
    Duration(seconds: 8),
    Duration(seconds: 30),
  ];

  Future<PushDrainResult>? _inflight;

  /// Drain up to [batch] ops from the head of the queue. Returns a
  /// summary the caller can use for logging / UI status. Never throws
  /// on individual op failures — those are captured on the op row and
  /// counted in the result.
  Future<PushDrainResult> drainOnce({int batch = 50}) {
    return _inflight ??= _run(batch).whenComplete(() => _inflight = null);
  }

  Future<PushDrainResult> _run(int batch) async {
    final ops = await _dao.head(limit: batch);
    var sent = 0;
    var retried = 0;
    var terminal = 0;
    var skippedBackoff = 0;

    for (final op in ops) {
      if (!_eligible(op)) {
        skippedBackoff++;
        continue;
      }

      final payload = _decodePayload(op);
      if (payload == null) {
        // Malformed local JSON — parking as terminal so we don't loop
        // on it forever, but keeping the row so a human can inspect.
        await _dao.incrementAttempts(op.id);
        await _dao.markFailure(op.id, 'malformed payload', _now());
        terminal++;
        continue;
      }

      final CloudUpsertResult result;
      try {
        result = await _cloud.upsertRow(
          table: op.entityTable,
          uuid: op.entityUuid,
          payload: payload,
        );
      } catch (e) {
        // A raw throw is treated as retryable — the CloudApi contract
        // says impls should classify results, but a rogue exception
        // shouldn't kill the drain loop.
        await _dao.incrementAttempts(op.id);
        await _dao.markFailure(op.id, 'threw: $e', _now());
        retried++;
        continue;
      }

      switch (result) {
        case CloudUpsertOk():
          await _dao.markSuccess(op.id);
          sent++;
        case CloudUpsertRetryable(:final reason):
          await _dao.incrementAttempts(op.id);
          await _dao.markFailure(op.id, reason, _now());
          retried++;
        case CloudUpsertTerminal(:final reason):
          await _dao.incrementAttempts(op.id);
          await _dao.markFailure(op.id, 'terminal: $reason', _now());
          terminal++;
      }
    }

    return PushDrainResult(
      inspected: ops.length,
      sent: sent,
      retried: retried,
      terminal: terminal,
      skippedBackoff: skippedBackoff,
    );
  }

  bool _eligible(PendingOpRow op) {
    final attempts = op.attempts;
    final wait = attempts < _backoffs.length
        ? _backoffs[attempts]
        : null; // null = past the schedule, skip until next manual trigger
    if (wait == null) return false;
    final last = op.lastAttemptAt;
    if (last == null) return true;
    return _now().difference(last) >= wait;
  }

  /// Removes the `id` column from the payload before pushing. Drift's
  /// autoincrement PK is device-local and has no meaning on the cloud
  /// side (which keys by uuid). Leaving it in would either break the
  /// upsert or, worse, silently collide with a different row that
  /// happens to have the same local id on another device.
  Map<String, dynamic>? _decodePayload(PendingOpRow op) {
    try {
      final raw = jsonDecode(op.payloadJson);
      if (raw is! Map<String, dynamic>) return null;
      return Map.of(raw)..remove('id');
    } catch (_) {
      return null;
    }
  }
}

/// Summary of one [PushWorker.drainOnce] run. `inspected` counts the
/// ops the worker looked at (before backoff filtering), the other
/// fields partition them by outcome.
class PushDrainResult {
  const PushDrainResult({
    required this.inspected,
    required this.sent,
    required this.retried,
    required this.terminal,
    required this.skippedBackoff,
  });

  final int inspected;
  final int sent;
  final int retried;
  final int terminal;
  final int skippedBackoff;
}
