import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/households_repository.dart';
import '../domain/household.dart';

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
