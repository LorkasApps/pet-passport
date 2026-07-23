import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/household.dart';
import '../domain/household_member.dart';

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

  /// Creates a household via the `create_household(text)` RPC. Direct
  /// INSERT INTO households from the client tripped RLS 42501 on release
  /// builds even after the same session had just written to
  /// `user_profiles` — see migration 0003 for the write-up. The RPC runs
  /// SECURITY DEFINER and does both the household row and the caller's
  /// owner-membership in one transaction, so we don't need a second
  /// round-trip either.
  Future<Household> create(String name) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('create called while signed out');
    final rows = await _client.rpc(
      'create_household',
      params: {'p_name': name.trim()},
    ) as List<dynamic>;
    if (rows.isEmpty) {
      throw StateError('create_household RPC returned no row');
    }
    final row = (rows.first as Map).cast<String, dynamic>();
    return Household(
      id: row['id'] as String,
      name: row['name'] as String,
      role: HouseholdRole.owner,
      memberCount: 1,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
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
  /// name is set. Returns the id of the household the user should treat
  /// as their primary — the freshly created one on first sign-in, or the
  /// oldest existing one on subsequent sign-ins.
  Future<String> ensureDefault(String defaultName) async {
    final mine = await listMine();
    if (mine.isNotEmpty) return mine.first.id;
    final created = await create(defaultName);
    return created.id;
  }

  /// Members of one household including each member's display name.
  /// PostgREST embed hits user_profiles under the FK — RLS on both
  /// tables restricts visibility to households I'm actually in.
  Future<List<HouseholdMember>> listMembersOf(String householdId) async {
    final rows = await _client
        .from('household_members')
        .select('user_id, role, joined_at, user_profiles(display_name)')
        .eq('household_id', householdId)
        .order('joined_at', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_memberFromRow)
        .toList(growable: false);
  }

  HouseholdMember _memberFromRow(Map<String, dynamic> row) {
    final profile = row['user_profiles'] as Map<String, dynamic>?;
    return HouseholdMember(
      userId: row['user_id'] as String,
      // If the profile row is missing (edge case: joined before setting a
      // display name) we fall back to the uuid's short prefix so the UI
      // has *something* to render.
      displayName: (profile?['display_name'] as String?) ??
          (row['user_id'] as String).substring(0, 6),
      role: householdRoleFromRaw(row['role'] as String?),
      joinedAt: DateTime.parse(row['joined_at'] as String),
    );
  }

  /// Owner removes another member. RLS enforces the owner-only
  /// restriction server-side; this method just issues the DELETE.
  Future<void> removeMember({
    required String householdId,
    required String userId,
  }) async {
    await _client
        .from('household_members')
        .delete()
        .eq('household_id', householdId)
        .eq('user_id', userId);
  }

  /// Current user leaves a household. The RLS DELETE policy on
  /// household_members allows self-removal.
  Future<void> leave(String householdId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('leave called while signed out');
    await _client
        .from('household_members')
        .delete()
        .eq('household_id', householdId)
        .eq('user_id', userId);
  }
}
