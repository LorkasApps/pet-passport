import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/notifications/notification_service.dart';
import '../data/settings_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsRepository(db.settingsDao);
});

// Onboarding
//
// StateNotifier — not a plain StreamProvider — so that a UI action can
// bump `state = true` synchronously *before* it navigates. Otherwise the
// router's redirect fires against a stale value: the write commits, but
// the DB watch stream propagates on a later microtask, so `context.go`
// still sees "onboarding not complete" and bounces the user right back
// to /onboarding. That produced a "Skip / Add do nothing" bug when the
// DB already held a pet but the onboarding flag had somehow reset.
class OnboardingController extends StateNotifier<bool> {
  OnboardingController(this._repo) : super(false) {
    _load();
    _sub = _repo
        .watchRaw(SettingsKeys.onboardingCompleted)
        .listen((v) => state = v == 'true');
  }

  final SettingsRepository _repo;
  late final StreamSubscription<String?> _sub;

  Future<void> _load() async {
    final raw = await _repo.getRaw(SettingsKeys.onboardingCompleted);
    state = raw == 'true';
  }

  Future<void> markCompleted() async {
    // Synchronous state bump: any refreshListenable-driven redirect that
    // runs on the very next frame now sees `true`.
    state = true;
    await _repo.setRaw(SettingsKeys.onboardingCompleted, 'true');
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, bool>((ref) {
  return OnboardingController(ref.watch(settingsRepositoryProvider));
});

// ThemeMode
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._repo) : super(ThemeMode.system) {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    final raw = await _repo.getRaw(SettingsKeys.themeMode);
    state = _parse(raw);
  }

  static ThemeMode _parse(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _repo.setRaw(SettingsKeys.themeMode, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(settingsRepositoryProvider));
});

// Locale
class LocaleController extends StateNotifier<Locale?> {
  LocaleController(this._repo) : super(null) {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    final raw = await _repo.getRaw(SettingsKeys.locale);
    if (raw != null && raw.isNotEmpty) {
      state = Locale(raw);
    }
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await _repo.remove(SettingsKeys.locale);
    } else {
      await _repo.setRaw(SettingsKeys.locale, locale.languageCode);
    }
  }
}

final localeProvider =
    StateNotifierProvider<LocaleController, Locale?>((ref) {
  return LocaleController(ref.watch(settingsRepositoryProvider));
});

// Reminder-Lead (days before the due date to fire the notification).
// Allowed values are curated on the settings screen; 7 days is the default.
class ReminderLeadController extends StateNotifier<int> {
  ReminderLeadController(this._repo) : super(defaultDays) {
    _load();
  }

  static const int defaultDays = 7;
  static const List<int> options = [1, 3, 7, 14, 30];

  final SettingsRepository _repo;

  Future<void> _load() async {
    final raw = await _repo.getRaw(SettingsKeys.reminderLeadDays);
    final parsed = int.tryParse(raw ?? '');
    if (parsed != null && parsed > 0) state = parsed;
  }

  Future<void> set(int days) async {
    state = days;
    await _repo.setRaw(SettingsKeys.reminderLeadDays, days.toString());
  }
}

final reminderLeadControllerProvider =
    StateNotifierProvider<ReminderLeadController, int>((ref) {
  return ReminderLeadController(ref.watch(settingsRepositoryProvider));
});

/// Read-only view for repositories that need the current value.
final reminderLeadDaysProvider = Provider<int>((ref) {
  return ref.watch(reminderLeadControllerProvider);
});
