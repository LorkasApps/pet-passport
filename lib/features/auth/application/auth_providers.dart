import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../data/auth_repository.dart';

/// Stream of auth-state changes from Supabase.
///
/// Emits [AuthChangeEvent.initialSession] on first subscribe (with the
/// cached session if one exists), then follow-ups for sign-in / sign-out
/// / token refresh / password recovery.
///
/// If Supabase isn't compile-time-configured we simply never emit — the
/// app then stays in local-only mode and the whole cloud UI is
/// unreachable.
final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  if (!SupabaseConfig.isConfigured) return const Stream.empty();
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Current user snapshot. `null` while unauthenticated or while running
/// in local-only mode.
final currentUserProvider = Provider<User?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  // Watching the stream ensures every rebuild re-reads the current
  // session — we don't have to plumb `AuthState.session?.user` through
  // every consumer.
  ref.watch(authStateStreamProvider);
  return Supabase.instance.client.auth.currentUser;
});

/// True while a session exists and hasn't been signed out yet. Cheap
/// derived provider so widgets can `ref.watch(isSignedInProvider)` and
/// rebuild only on true→false or false→true transitions.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
