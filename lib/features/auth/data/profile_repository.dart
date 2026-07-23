import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/user_profile.dart';

/// Reads and writes `public.user_profiles`. Kept slim on purpose — the
/// only two operations we need in M1 are 'do I already have a profile?'
/// and 'save my display name'.
class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<UserProfile?> fetchMine() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('user_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : UserProfile.fromMap(row);
  }

  /// Upsert on user_id — sign-up creates the row, later edits update it
  /// in place. Server enforces `char_length(display_name) BETWEEN 1 AND
  /// 60` via CHECK, so a trimmed empty string will be rejected.
  Future<UserProfile> saveDisplayName(String displayName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('saveDisplayName called while signed out');
    }
    final row = await _client
        .from('user_profiles')
        .upsert({
          'user_id': userId,
          'display_name': displayName.trim(),
        })
        .select()
        .single();
    return UserProfile.fromMap(row);
  }
}
