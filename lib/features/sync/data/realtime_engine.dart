import 'dart:async';

import 'pull_engine.dart';
import 'realtime_source.dart';

/// Owns one realtime subscription per top-level table, filtered by
/// the household set. Every incoming row-change gets handed to
/// [PullEngine.applyRow] — the same code path a delta pull uses,
/// so realtime and pull share LWW + FK-resolution + tombstone
/// handling by construction.
///
/// The engine emits a [RealtimeStatus] stream so the AppBar
/// indicator (M4 UI) and app-level fallback-to-pull can react.
class RealtimeEngine {
  RealtimeEngine(this._source, this._pull);

  final RealtimeSource _source;
  final PullEngine _pull;
  final List<RealtimeSubscription> _subs = [];
  final StreamController<RealtimeStatus> _status =
      StreamController<RealtimeStatus>.broadcast();
  final StreamController<void> _disconnects =
      StreamController<void>.broadcast();

  /// Top-level tables the engine subscribes to. Matches [PullEngine]'s
  /// scope — helper tables like pet_weights/event_tags stay
  /// pull-only for now (M3 followup).
  static const _tables = <String>[
    'pets',
    'vets',
    'contacts',
    'foods',
    'insurances',
    'events',
    'pet_documents',
    'vaccinations',
    'medications',
    'appointments',
  ];

  Stream<RealtimeStatus> get status => _status.stream;

  /// Fires every time a subscription reports a disconnect. The app
  /// wires a poll-pull to this so a network blip doesn't drop
  /// changes.
  Stream<void> get onDisconnect => _disconnects.stream;

  /// Start subscribing. If already running, tears down first so a
  /// household-set change (join/leave) reconfigures cleanly.
  Future<void> start({required List<String> householdIds}) async {
    stop();
    if (householdIds.isEmpty) {
      _status.add(RealtimeStatus.idle);
      return;
    }
    for (final table in _tables) {
      final sub = _source.subscribeChanges(
        table: table,
        householdIds: householdIds,
        onChange: _handle,
        onDisconnect: _onDisconnect,
      );
      _subs.add(sub);
    }
    _status.add(RealtimeStatus.connected);
  }

  void stop() {
    for (final s in _subs) {
      s.dispose();
    }
    _subs.clear();
    _status.add(RealtimeStatus.idle);
  }

  /// For test / debug: how many subscriptions are currently active.
  int get activeSubscriptionCount => _subs.length;

  Future<void> _handle(RealtimeChange change) async {
    // DELETE payloads only carry the PK by default (unless the table
    // sets REPLICA IDENTITY FULL). Our tombstones ride as UPDATE
    // events with `deleted_at` set — that path has all the data.
    final row = change.newRow ?? change.oldRow;
    if (row == null) return;
    try {
      await _pull.applyRow(change.table, row);
    } catch (_) {
      // Best-effort — realtime is a nice-to-have; the delta pull is
      // the safety net. Swallow so one bad row doesn't kill the
      // dispatch loop.
    }
  }

  void _onDisconnect() {
    _status.add(RealtimeStatus.disconnected);
    _disconnects.add(null);
  }

  Future<void> dispose() async {
    stop();
    await _status.close();
    await _disconnects.close();
  }
}

/// High-level connection state exposed to the UI. Fine-grained
/// per-subscription states get collapsed into these four.
enum RealtimeStatus {
  /// No active subscriptions (not signed in, no households, or
  /// stop() was called).
  idle,

  /// Subscriptions are open and healthy.
  connected,

  /// At least one subscription reported a disconnect. The channel
  /// itself will retry; the app should also fire a fallback pull.
  disconnected,
}
