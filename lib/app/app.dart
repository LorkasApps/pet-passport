import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../features/appointments/application/appointments_providers.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/diet/application/foods_providers.dart';
import '../features/households/application/households_providers.dart';
import '../features/households/data/household_stamper.dart';
import '../features/households/domain/household.dart';
import '../features/medications/application/medications_providers.dart';
import '../features/pets/application/current_pet_provider.dart';
import '../features/pets/application/pets_providers.dart';
import '../features/security/presentation/app_lock_gate.dart';
import '../features/settings/application/settings_providers.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/sync/application/sync_providers.dart';
import '../features/vaccinations/application/vaccinations_providers.dart';
import 'router.dart';
import 'theme.dart';

class PetPassportApp extends ConsumerStatefulWidget {
  const PetPassportApp({super.key});

  @override
  ConsumerState<PetPassportApp> createState() => _PetPassportAppState();
}

class _PetPassportAppState extends ConsumerState<PetPassportApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Wire notification taps to router deep-links once the app is built.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notif = ref.read(notificationServiceProvider);
      // Ask for notification + exact-alarm permission on first launch.
      await notif.requestPermissions();
      notif.setTapHandler((payload) async {
        final router = ref.read(routerProvider);
        final pet = await ref.read(currentPetProvider.future);
        if (payload.entity == 'vac') {
          if (pet != null) {
            unawaited(router
                .push('/pets/${pet.uuid}/vaccinations/${payload.uuid}'));
          } else {
            unawaited(router.push('/vaccinations'));
          }
        } else if (payload.entity == 'appt') {
          if (pet != null) {
            unawaited(router
                .push('/pets/${pet.uuid}/appointments/${payload.uuid}'));
          } else {
            unawaited(router.push('/appointments'));
          }
        } else if (payload.entity == 'med') {
          final autoLog = payload.extra['action'] == 'log' ? '?log=1' : '';
          if (pet != null) {
            unawaited(router.push(
                '/pets/${pet.uuid}/medications/${payload.uuid}$autoLog'));
          } else {
            unawaited(router.push('/medications'));
          }
        } else if (payload.entity == 'feed') {
          if (pet != null) {
            unawaited(router.push('/diet'));
          } else {
            unawaited(router.push('/diet'));
          }
        }
      });
      await _rescheduleAll();
      // Prune orphan media once per cold start.
      await _sweepMedia();
    });

    // React to reminder-lead changes: user picks 3 days instead of 7, all
    // future notifications shift accordingly.
    ref.listenManual(reminderLeadControllerProvider, (previous, next) async {
      if (previous == null || previous == next) return;
      await ref
          .read(vaccinationsRepositoryProvider)
          .rescheduleAllUpcomingReminders();
    });

    // Bootstrap-adopt local pre-cloud rows into the primary household
    // any time we have a household to bind them to. Runs on every
    // non-empty myHouseholdsProvider emission, but the stamper's
    // `WHERE household_id IS NULL` guard makes the second and every
    // subsequent call a no-op — and the enqueue step is snapshotted
    // BEFORE the update, so already-stamped rows never re-enqueue.
    //
    // This is the safety net for returning users whose display-name
    // profile already existed cloud-side: the display-name onboarding
    // screen is skipped for them, so the stamp used to never run.
    ref.listenManual<AsyncValue<List<Household>>>(
      myHouseholdsProvider,
      (_, next) async {
        final list = next.value;
        if (list == null || list.isEmpty) return;
        if (!ref.read(isSignedInProvider)) return;
        final primary = list.first.id;
        await HouseholdStamper(ref.read(databaseProvider)).stampNullRows(
          primary,
          outbox: ref.read(syncOutboxProvider),
        );
      },
      fireImmediately: true,
    );

    // Push-sync driver: every time the outbox grows, kick a drain.
    // Single-flight inside the worker collapses bursts; guarded on
    // sign-in so we don't burn retries against a 401 while offline of
    // Supabase. When cloud isn't configured, pushWorkerProvider is
    // null and this listener is a no-op.
    ref.listenManual<AsyncValue<int>>(
      pendingOpsCountProvider,
      (_, next) {
        final count = next.value ?? 0;
        if (count == 0) return;
        if (!ref.read(isSignedInProvider)) return;
        unawaited(ref.read(pushWorkerProvider)?.drainOnce() ?? Future.value());
      },
      fireImmediately: true,
    );

    // Pull-sync driver: every time the households list resolves to
    // non-empty (which is the point at which we have something to
    // filter the RLS scope on), kick a pull. Also runs at sign-in
    // transitions because the households list rebuilds then.
    ref.listenManual<AsyncValue<List<Household>>>(
      myHouseholdsProvider,
      (_, next) {
        final list = next.value;
        if (list == null || list.isEmpty) return;
        if (!ref.read(isSignedInProvider)) return;
        _kickPull(list);
      },
      fireImmediately: true,
    );
  }

  Future<void> _kickPull(List<Household> households) async {
    final engine = ref.read(pullEngineProvider);
    if (engine == null) return;
    final ids = households.map((h) => h.id).toList(growable: false);
    try {
      await _maybeResetCursorsForNewScope(ids);
      await engine.pullOnce(householdIds: ids);
    } catch (_) {
      // Best-effort background pull — a transient network hiccup
      // shouldn't kill the app. The cursor is only advanced on
      // successful pages inside the engine, so the next kick picks
      // up where we left off.
    }
  }

  /// When the household membership set grows (user joined a new one),
  /// the pre-existing rows in that household have updated_at older
  /// than any current cursor. A plain delta pull would skip them.
  /// Wipe every cursor once so the next pullOnce sees them all.
  ///
  /// We only invalidate on strict growth. Shrinking (leave / kick)
  /// isn't a data-visibility risk — those rows just stop being
  /// returned by RLS, and the local copies stay put until the next
  /// leave-side cleanup lands (M6).
  Future<void> _maybeResetCursorsForNewScope(List<String> ids) async {
    final settings = ref.read(settingsRepositoryProvider);
    final current = ([...ids]..sort()).join(',');
    final previous =
        await settings.getRaw(SettingsKeys.lastPullScopeHouseholds);
    if (previous != current) {
      final prevSet = previous?.split(',').where((s) => s.isNotEmpty).toSet() ??
          const <String>{};
      final currSet = ids.toSet();
      // Reset only on strict growth. Same set (order sanity) or
      // shrinkage keeps existing cursors.
      final grew = currSet.difference(prevSet).isNotEmpty;
      if (grew) {
        await ref.read(databaseProvider).syncCursorsDao.resetAll();
      }
      await settings.setRaw(SettingsKeys.lastPullScopeHouseholds, current);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-run the scheduler when the app comes back to the foreground so a
    // TZ change or system-clock adjustment is picked up without a restart.
    // Deterministic IDs keep this idempotent — no duplicate notifications.
    if (state == AppLifecycleState.resumed) {
      unawaited(_rescheduleAll());
      // Also drain any ops that piled up while backgrounded AND pull
      // any changes other devices made in the meantime. Guard on
      // sign-in — pure-local users have nothing to sync anyway.
      if (ref.read(isSignedInProvider)) {
        unawaited(
          ref.read(pushWorkerProvider)?.drainOnce() ?? Future.value(),
        );
        final households =
            ref.read(myHouseholdsProvider).valueOrNull ?? const [];
        if (households.isNotEmpty) {
          unawaited(_kickPull(households));
        }
      }
    }
  }

  Future<void> _sweepMedia() async {
    try {
      final media = ref.read(mediaServiceProvider);
      final db = ref.read(databaseProvider);
      await media.sweep(db);
    } catch (_) {
      // best-effort startup housekeeping — never fatal.
    }
  }

  Future<void> _rescheduleAll() async {
    await ref
        .read(vaccinationsRepositoryProvider)
        .rescheduleAllUpcomingReminders();
    await ref
        .read(appointmentsRepositoryProvider)
        .rescheduleAllUpcomingReminders();
    await ref
        .read(medicationsRepositoryProvider)
        .rescheduleAllUpcomingReminders();
    await ref
        .read(foodsRepositoryProvider)
        .rescheduleAllUpcomingReminders();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppL10n.of(context).appTitle,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: AppL10n.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
      debugShowCheckedModeBanner: false,
    );
  }
}
