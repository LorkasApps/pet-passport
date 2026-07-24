import 'package:pet_passport/features/sync/data/realtime_source.dart';

/// In-memory [RealtimeSource] double. Tests can [emit] a change and
/// the engine handles it as if it came from Supabase's realtime
/// channel. [disconnect] fires the onDisconnect callback on every
/// active subscription.
class FakeRealtimeSource implements RealtimeSource {
  final List<FakeSub> subs = [];

  @override
  RealtimeSubscription subscribeChanges({
    required String table,
    required List<String> householdIds,
    required void Function(RealtimeChange change) onChange,
    void Function()? onDisconnect,
  }) {
    final sub = FakeSub(this, table, householdIds, onChange, onDisconnect);
    subs.add(sub);
    return sub;
  }

  /// Deliver a change to every matching subscription (table +
  /// household filter). Multiple channels for the same table are
  /// possible during a reconfigure; matching all keeps behavior
  /// realistic.
  void emit(RealtimeChange change) {
    final hid = (change.newRow ?? change.oldRow)?['household_id'] as String?;
    for (final sub in subs) {
      if (sub.table != change.table) continue;
      if (hid != null && !sub.householdIds.contains(hid)) continue;
      sub.onChange(change);
    }
  }

  void disconnect() {
    for (final sub in subs) {
      sub.onDisconnect?.call();
    }
  }

  int get activeCount => subs.length;
}

class FakeSub implements RealtimeSubscription {
  FakeSub(
    this._parent,
    this.table,
    this.householdIds,
    this.onChange,
    this.onDisconnect,
  );

  final FakeRealtimeSource _parent;
  final String table;
  final List<String> householdIds;
  final void Function(RealtimeChange) onChange;
  final void Function()? onDisconnect;

  @override
  void dispose() {
    _parent.subs.remove(this);
  }
}
