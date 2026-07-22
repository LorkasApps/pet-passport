import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../settings/application/settings_providers.dart';
import '../../settings/data/settings_repository.dart';

final localAuthProvider = Provider<LocalAuthentication>((_) {
  return LocalAuthentication();
});

/// Whether the app-lock is enabled by the user. Stored in settings.
class AppLockEnabledController extends StateNotifier<bool> {
  AppLockEnabledController(this._repo) : super(false) {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    final raw = await _repo.getRaw(SettingsKeys.appLockEnabled);
    state = raw == 'true';
  }

  Future<void> set(bool value) async {
    state = value;
    await _repo.setRaw(SettingsKeys.appLockEnabled, value ? 'true' : 'false');
  }
}

final appLockEnabledProvider =
    StateNotifierProvider<AppLockEnabledController, bool>((ref) {
  return AppLockEnabledController(ref.watch(settingsRepositoryProvider));
});

/// Whether the current process is currently authenticated. Transient —
/// resets on cold start and on lifecycle-based re-locks.
final authenticatedProvider = StateProvider<bool>((_) => false);

/// True when the device actually offers a biometric or device-credential
/// challenge. If false, the user cannot enable the lock.
final canAuthenticateProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(localAuthProvider);
  try {
    final supported = await auth.isDeviceSupported();
    if (!supported) return false;
    return await auth.canCheckBiometrics ||
        (await auth.getAvailableBiometrics()).isNotEmpty;
  } catch (e) {
    if (kDebugMode) debugPrint('canAuthenticate failed: $e');
    return false;
  }
});
