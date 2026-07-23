import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Boots up the Supabase client if the build-time config is present.
///
/// Safe to call unconditionally at startup: if either env var is empty the
/// function returns without touching anything, and every downstream call
/// site is expected to guard with [SupabaseConfig.isConfigured] before
/// reaching into the client.
///
/// Session storage uses the SDK's default local storage (Hive-backed,
/// scoped to the app's private data dir). Encrypted-at-rest via
/// flutter_secure_storage is a documented M7 hardening item — Hive on a
/// sandboxed app dir is defensible for M1's threat model (device theft
/// with device-level lock is the primary concern; Keystore wouldn't
/// help if the user chose no lock in the OS).
Future<void> initSupabaseIfConfigured() async {
  if (!SupabaseConfig.isConfigured) return;
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // `publishableKey` replaced `anonKey` in supabase_flutter's post-2024
    // key nomenclature — same value, renamed param.
    publishableKey: SupabaseConfig.publishableKey,
    authOptions: const FlutterAuthClientOptions(
      // PKCE is the recommended flow for public mobile clients — no
      // client secret involved, guards the token exchange against
      // network interception.
      authFlowType: AuthFlowType.pkce,
    ),
  );
}
