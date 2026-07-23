import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/user_profile.dart';
import 'auth_providers.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

/// Current user's profile, or null if none exists yet (i.e. the display
/// name has never been set). Re-fetched whenever the auth user changes,
/// so signing out and back in with a different account picks up the
/// right profile.
///
/// AsyncNotifier over a plain FutureProvider because we need an
/// imperative `saveDisplayName` that mutates state and re-emits.
class MyProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    // Re-run when the auth user changes; signed-out → null.
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;
    return ref.read(profileRepositoryProvider).fetchMine();
  }

  Future<void> saveDisplayName(String name) async {
    state = const AsyncLoading();
    try {
      final saved =
          await ref.read(profileRepositoryProvider).saveDisplayName(name);
      state = AsyncData(saved);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final myProfileProvider =
    AsyncNotifierProvider<MyProfileNotifier, UserProfile?>(
  MyProfileNotifier.new,
);

/// Convenience: true when a signed-in user still has no persisted
/// profile row. Used by the router to gate `/home` behind the display-
/// name onboarding.
final needsDisplayNameProvider = Provider<bool>((ref) {
  final signedIn = ref.watch(isSignedInProvider);
  if (!signedIn) return false;
  final profile = ref.watch(myProfileProvider);
  return profile.when(
    data: (p) => p == null,
    loading: () => false, // don't kick the user around while loading
    error: (_, _) => false, // network hiccup shouldn't force the screen
  );
});
