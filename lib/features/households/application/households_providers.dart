import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/households_repository.dart';
import '../data/invite_repository.dart';
import '../domain/household.dart';
import '../domain/household_member.dart';
import '../domain/invite_code.dart';

final householdsRepositoryProvider = Provider<HouseholdsRepository>((ref) {
  return HouseholdsRepository();
});

/// AsyncNotifier so we can imperatively invalidate after create /
/// rename / delete without a full stream setup. Realtime push comes in
/// M4; for M1 we refetch on demand and on auth-user changes.
class MyHouseholdsNotifier extends AsyncNotifier<List<Household>> {
  @override
  Future<List<Household>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return ref.read(householdsRepositoryProvider).listMine();
  }

  Future<void> refresh() async => ref.invalidateSelf();

  Future<Household> create(String name) async {
    final h = await ref.read(householdsRepositoryProvider).create(name);
    ref.invalidateSelf();
    return h;
  }

  Future<Household> rename(String id, String name) async {
    final h =
        await ref.read(householdsRepositoryProvider).rename(id, name);
    ref.invalidateSelf();
    return h;
  }

  Future<void> delete(String id) async {
    await ref.read(householdsRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final myHouseholdsProvider =
    AsyncNotifierProvider<MyHouseholdsNotifier, List<Household>>(
  MyHouseholdsNotifier.new,
);

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return InviteRepository();
});

/// Family-per-household. Watches the active codes for one household and
/// exposes imperative generate / revoke.
class HouseholdInvitesNotifier
    extends FamilyAsyncNotifier<List<InviteCode>, String> {
  @override
  Future<List<InviteCode>> build(String householdId) {
    return ref.read(inviteRepositoryProvider).activeFor(householdId);
  }

  Future<InviteCode> generate() async {
    final code = await ref
        .read(inviteRepositoryProvider)
        .generate(arg);
    ref.invalidateSelf();
    return code;
  }

  Future<void> revoke(String inviteId) async {
    await ref.read(inviteRepositoryProvider).revoke(inviteId);
    ref.invalidateSelf();
  }
}

final householdInvitesProvider = AsyncNotifierProvider.family<
    HouseholdInvitesNotifier, List<InviteCode>, String>(
  HouseholdInvitesNotifier.new,
);

/// Members of one household, keyed by household id. Refetched after
/// remove/leave so the UI updates without a full page reload.
class HouseholdMembersNotifier
    extends FamilyAsyncNotifier<List<HouseholdMember>, String> {
  @override
  Future<List<HouseholdMember>> build(String householdId) {
    return ref
        .read(householdsRepositoryProvider)
        .listMembersOf(householdId);
  }

  Future<void> removeMember(String userId) async {
    await ref.read(householdsRepositoryProvider).removeMember(
          householdId: arg,
          userId: userId,
        );
    ref.invalidateSelf();
    // Household summary caches member count — invalidate it too.
    ref.invalidate(myHouseholdsProvider);
  }

  Future<void> leave() async {
    await ref.read(householdsRepositoryProvider).leave(arg);
    ref.invalidate(myHouseholdsProvider);
  }
}

final householdMembersProvider = AsyncNotifierProvider.family<
    HouseholdMembersNotifier, List<HouseholdMember>, String>(
  HouseholdMembersNotifier.new,
);
