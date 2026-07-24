import 'package:supabase_flutter/supabase_flutter.dart';

import 'realtime_source.dart';

/// Real [RealtimeSource] backed by Supabase's realtime channel. One
/// channel per (table, household-scope) pair — cheap enough for a
/// household count in single digits, and keeps the filter simple.
class SupabaseRealtimeSource implements RealtimeSource {
  SupabaseRealtimeSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  RealtimeSubscription subscribeChanges({
    required String table,
    required List<String> householdIds,
    required void Function(RealtimeChange change) onChange,
    void Function()? onDisconnect,
  }) {
    // A unique channel name per table keeps `postgres_changes`
    // subscriptions isolated on the server side. Household filter
    // goes through the `filter` param — the client-side callback then
    // only fires for rows we can see. RLS still applies on top on the
    // server, so a leaked filter isn't a security issue.
    final channel = _client.channel('feat-$table');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: householdIds.length == 1
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'household_id',
              value: householdIds.first,
            )
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.inFilter,
              column: 'household_id',
              value: householdIds,
            ),
      callback: (payload) {
        onChange(
          RealtimeChange(
            table: table,
            type: _translate(payload.eventType),
            newRow: payload.newRecord.isEmpty
                ? null
                : Map<String, dynamic>.from(payload.newRecord),
            oldRow: payload.oldRecord.isEmpty
                ? null
                : Map<String, dynamic>.from(payload.oldRecord),
          ),
        );
      },
    );
    channel.subscribe((status, [error]) {
      // The channel drives its own reconnection loop; we only surface
      // "we lost it" so the outer engine can trigger a fallback pull
      // once we come back.
      if (status == RealtimeSubscribeStatus.closed ||
          status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        onDisconnect?.call();
      }
    });
    return _ChannelHandle(channel);
  }

  RealtimeChangeType _translate(PostgresChangeEvent e) {
    switch (e) {
      case PostgresChangeEvent.insert:
        return RealtimeChangeType.insert;
      case PostgresChangeEvent.update:
        return RealtimeChangeType.update;
      case PostgresChangeEvent.delete:
        return RealtimeChangeType.delete;
      case PostgresChangeEvent.all:
        // `all` is a filter subscription mode, not a delivered event
        // — shouldn't reach here. Treat as update to fail soft.
        return RealtimeChangeType.update;
    }
  }
}

class _ChannelHandle implements RealtimeSubscription {
  _ChannelHandle(this._channel);
  final RealtimeChannel _channel;

  @override
  void dispose() {
    _channel.unsubscribe();
  }
}
