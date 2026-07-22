import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../features/appointments/application/appointments_providers.dart';
import '../features/medications/application/medications_providers.dart';
import '../features/pets/application/current_pet_provider.dart';
import '../features/security/presentation/app_lock_gate.dart';
import '../features/settings/application/settings_providers.dart';
import '../features/vaccinations/application/vaccinations_providers.dart';
import 'router.dart';
import 'theme.dart';

class PetPassportApp extends ConsumerStatefulWidget {
  const PetPassportApp({super.key});

  @override
  ConsumerState<PetPassportApp> createState() => _PetPassportAppState();
}

class _PetPassportAppState extends ConsumerState<PetPassportApp> {
  @override
  void initState() {
    super.initState();
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
        }
      });
      // Re-arm scheduled reminders after cold start / reboot / permission
      // changes. Deterministic IDs keep this idempotent.
      await ref
          .read(vaccinationsRepositoryProvider)
          .rescheduleAllUpcomingReminders();
      await ref
          .read(appointmentsRepositoryProvider)
          .rescheduleAllUpcomingReminders();
      await ref
          .read(medicationsRepositoryProvider)
          .rescheduleAllUpcomingReminders();
    });

    // React to reminder-lead changes: user picks 3 days instead of 7, all
    // future notifications shift accordingly.
    ref.listenManual(reminderLeadControllerProvider, (previous, next) async {
      if (previous == null || previous == next) return;
      await ref
          .read(vaccinationsRepositoryProvider)
          .rescheduleAllUpcomingReminders();
    });
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
