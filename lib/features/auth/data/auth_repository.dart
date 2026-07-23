import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over Supabase auth for the operations the app performs
/// directly. Keeps the widget layer free of the SDK type surface and
/// gives us one place to mock in tests.
class AuthRepository {
  AuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Deep-link the auth callback into the app instead of a browser
  /// landing page. Registered on the Supabase side under
  /// Authentication → URL Configuration.
  static const authCallbackUrl = 'petpassport://auth/callback';

  /// Kick off a magic-link sign-in. Supabase sends the mail; the user
  /// clicks the link on their phone; the OS routes back into the app
  /// via the [authCallbackUrl] scheme; the SDK's built-in deep-link
  /// observer completes the PKCE exchange and emits an auth event.
  Future<void> sendMagicLink(String email) {
    return _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: authCallbackUrl,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
