import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/household.dart';

/// CRUD for households the current user is a member of. Server-side RLS
/// keeps every method automatically scoped: the caller only ever sees /
/// mutates households they belong to (or ones they own, for the
/// state-changing ops).
class HouseholdsRepository {
  HouseholdsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetches my households and — via the embedded members — the role I
  /// hold in each and the total member count. PostgREST returns one
  /// join per row; fine for 1–5 households per user.
  Future<List<Household>> listMine() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('households')
        .select('id, name, created_at, household_members(user_id, role)')
        .order('created_at', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => _rowToDomain(r, userId))
        .toList(growable: false);
  }

  Household _rowToDomain(Map<String, dynamic> row, String userId) {
    final members = (row['household_members'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final mine = members.firstWhere(
      (m) => m['user_id'] == userId,
      orElse: () => <String, dynamic>{'role': 'member'},
    );
    return Household(
      id: row['id'] as String,
      name: row['name'] as String,
      role: householdRoleFromRaw(mine['role'] as String?),
      memberCount: members.length,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// Inserts a household. The `tg_household_creator_becomes_owner`
  /// trigger on the DB side inserts the caller as owner in
  /// `household_members`, so we don't have to make a second round-trip.
  Future<Household> create(String name) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('create called while signed out');
    final row = await _client
        .from('households')
        .insert({'name': name.trim(), 'created_by': userId})
        .select('id, name, created_at, household_members(user_id, role)')
        .single();
    return _rowToDomain(row, userId);
  }

  Future<Household> rename(String id, String name) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('rename called while signed out');
    final row = await _client
        .from('households')
        .update({'name': name.trim()})
        .eq('id', id)
        .select('id, name, created_at, household_members(user_id, role)')
        .single();
    return _rowToDomain(row, userId);
  }

  Future<void> delete(String id) async {
    await _client.from('households').delete().eq('id', id);
  }

  /// Idempotent bootstrap: if the caller has zero memberships, create a
  /// default household so subsequent screens have something to bind
  /// pets and events to. Called from the sign-up flow after the display
  /// name is set.
  Future<void> ensureDefault(String defaultName) async {
    final mine = await listMine();
    if (mine.isNotEmpty) return;
    await create(defaultName);
  }
}
