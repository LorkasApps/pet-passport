import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Returns the Supabase auth user-id if the client is initialised AND a
/// session is present. `null` in every other case — including
/// unconfigured builds — so repositories can call it unconditionally
/// when stamping `updated_by_user_id` on writes.
String? currentUserId() {
  if (!SupabaseConfig.isConfigured) return null;
  return Supabase.instance.client.auth.currentUser?.id;
}
