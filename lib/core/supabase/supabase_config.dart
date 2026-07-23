/// Compile-time Supabase configuration.
///
/// Values are injected at build time via `--dart-define`. See the top-level
/// `README.md` (Cloud/M1 section) for the concrete flags. If both values
/// are empty the app runs in **pure local mode** — no auth, no sync, no
/// household sharing — which is the same behavior the app has always
/// had. That's the fallback we keep working so existing solo users are
/// never forced into the cloud story.
class SupabaseConfig {
  const SupabaseConfig._();

  static const url =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');

  /// True iff both values look plausible. We do a minimal shape check so
  /// a copy-paste mistake (spaces, wrong var, half a JWT) fails at boot
  /// with a clear error instead of surfacing as auth failures later.
  static bool get isConfigured =>
      url.startsWith('https://') && publishableKey.length > 20;
}
