import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/invite_code.dart';

class InviteRepository {
  InviteRepository({SupabaseClient? client, Random? random})
      : _client = client ?? Supabase.instance.client,
        _random = random ?? Random.secure();

  final SupabaseClient _client;
  final Random _random;

  static const Duration _ttl = Duration(hours: 24);

  /// Alphabet chosen to be typeable: no 0/O, no 1/I/L, no U — the
  /// classic OCR-ish confusables. 30 symbols × 8 chars = ~39 bits of
  /// entropy, plenty for a 24h TTL under server-side rate limiting.
  static const _alphabet = '23456789ABCDEFGHJKLMNPQRSTVWXYZ';

  String _generateToken() {
    return List.generate(
      8,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
  }

  Future<List<InviteCode>> activeFor(String householdId) async {
    final rows = await _client
        .from('invite_codes')
        .select()
        .eq('household_id', householdId)
        .isFilter('used_at', null)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(InviteCode.fromRow)
        .toList(growable: false);
  }

  Future<InviteCode> generate(String householdId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('signed out');
    final token = _generateToken();
    final row = await _client
        .from('invite_codes')
        .insert({
          'household_id': householdId,
          'token': token,
          'created_by': userId,
          'expires_at':
              DateTime.now().toUtc().add(_ttl).toIso8601String(),
        })
        .select()
        .single();
    return InviteCode.fromRow(row);
  }

  /// Revoke = delete. `used_at` is reserved for successful redemption
  /// so we don't overload semantics.
  Future<void> revoke(String inviteId) async {
    await _client.from('invite_codes').delete().eq('id', inviteId);
  }

  /// Consume a token via the SECURITY DEFINER RPC on the DB side. Adds
  /// the current user as member, flips `used_at`, returns a summary of
  /// the household we just joined. Throws whatever Postgres error the
  /// RPC surfaced (invalid / expired / already used — see
  /// 0001_multiuser_bootstrap.sql for the concrete error strings).
  Future<InviteRedemptionResult> redeem(String rawToken) async {
    // Accept 'X4KM-9RTW' with or without the visual hyphen and any
    // stray whitespace / case the user may have pasted or spoken.
    final token = rawToken.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    final rows =
        await _client.rpc('redeem_invite', params: {'p_token': token}) as List;
    if (rows.isEmpty) {
      // Shouldn't happen — the RPC always returns a row on success.
      throw StateError('redeem_invite returned no row');
    }
    final first = rows.first as Map<String, dynamic>;
    return InviteRedemptionResult(
      householdId: first['household_id'] as String,
      householdName: first['household_name'] as String,
      memberCount: (first['member_count'] as num).toInt(),
    );
  }
}

class InviteRedemptionResult {
  const InviteRedemptionResult({
    required this.householdId,
    required this.householdName,
    required this.memberCount,
  });

  final String householdId;
  final String householdName;
  final int memberCount;
}
