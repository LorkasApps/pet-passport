import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../application/app_lock_providers.dart';

/// Wraps the app UI and gates it behind biometric/device-credential auth
/// when the user enabled the lock. Re-locks whenever the app goes into
/// background so a passer-by grabbing the phone hits the lock screen.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _promptInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAuthenticate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Lock as soon as the app leaves the foreground.
      ref.read(authenticatedProvider.notifier).state = false;
    } else if (state == AppLifecycleState.resumed) {
      _maybeAuthenticate();
    }
  }

  Future<void> _maybeAuthenticate() async {
    if (_promptInFlight) return;
    final enabled = ref.read(appLockEnabledProvider);
    if (!enabled) {
      ref.read(authenticatedProvider.notifier).state = true;
      return;
    }
    if (ref.read(authenticatedProvider)) return;
    _promptInFlight = true;
    try {
      final auth = ref.read(localAuthProvider);
      final l = AppL10n.of(context);
      final ok = await auth.authenticate(
        localizedReason: l.appLockReason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (mounted) {
        ref.read(authenticatedProvider.notifier).state = ok;
      }
    } catch (_) {
      // On error, leave locked — user can retry with the button.
    } finally {
      _promptInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(appLockEnabledProvider);
    final authenticated = ref.watch(authenticatedProvider);
    if (!enabled || authenticated) {
      return widget.child;
    }
    return _LockScreen(onRetry: _maybeAuthenticate);
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 96, color: scheme.primary),
              const SizedBox(height: 24),
              Text(
                l.appLockLockedTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l.appLockLockedBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.fingerprint),
                label: Text(l.appLockUnlock),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
