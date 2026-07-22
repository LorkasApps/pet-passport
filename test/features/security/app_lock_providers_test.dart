import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_passport/features/security/application/app_lock_providers.dart';
import 'package:pet_passport/features/settings/application/settings_providers.dart';
import 'package:pet_passport/features/settings/data/settings_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  group('AppLock Providers', () {
    late MockSettingsRepository mockSettingsRepo;
    late MockLocalAuthentication mockLocalAuth;

    setUp(() {
      mockSettingsRepo = MockSettingsRepository();
      mockLocalAuth = MockLocalAuthentication();
    });

    group('appLockEnabledProvider', () {
      test('defaults to false on initial load when setting is not set', () async {
        // When getRaw returns null (setting doesn't exist), controller should be false
        when(
          () => mockSettingsRepo.getRaw(SettingsKeys.appLockEnabled),
        ).thenAnswer((_) async => null);

        final container = ProviderContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
          ],
        );
        addTearDown(container.dispose);

        // Force construction of the controller so _load() actually runs,
        // then drain the microtask queue so the async load resolves.
        container.read(appLockEnabledProvider);
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        expect(
          container.read(appLockEnabledProvider),
          false,
        );
      });

      test('loads existing enabled state from repository', () async {
        when(
          () => mockSettingsRepo.getRaw(SettingsKeys.appLockEnabled),
        ).thenAnswer((_) async => 'true');

        final container = ProviderContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
          ],
        );
        addTearDown(container.dispose);

        container.read(appLockEnabledProvider);
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        expect(
          container.read(appLockEnabledProvider),
          true,
        );
      });

      test('loads disabled state from repository', () async {
        when(
          () => mockSettingsRepo.getRaw(SettingsKeys.appLockEnabled),
        ).thenAnswer((_) async => 'false');

        final container = ProviderContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
          ],
        );
        addTearDown(container.dispose);

        container.read(appLockEnabledProvider);
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        expect(
          container.read(appLockEnabledProvider),
          false,
        );
      });

      test('enables app-lock and persists to repository', () async {
        when(
          () => mockSettingsRepo.getRaw(SettingsKeys.appLockEnabled),
        ).thenAnswer((_) async => null);
        when(
          () => mockSettingsRepo.setRaw(
            SettingsKeys.appLockEnabled,
            any(),
          ),
        ).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
          ],
        );
        addTearDown(container.dispose);

        container.read(appLockEnabledProvider);
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        final notifier = container.read(appLockEnabledProvider.notifier);
        await notifier.set(true);

        expect(container.read(appLockEnabledProvider), true);
        verify(
          () => mockSettingsRepo.setRaw(
            SettingsKeys.appLockEnabled,
            'true',
          ),
        ).called(1);
      });

      test('disables app-lock and persists to repository', () async {
        when(
          () => mockSettingsRepo.getRaw(SettingsKeys.appLockEnabled),
        ).thenAnswer((_) async => 'true');
        when(
          () => mockSettingsRepo.setRaw(
            SettingsKeys.appLockEnabled,
            any(),
          ),
        ).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
          ],
        );
        addTearDown(container.dispose);

        container.read(appLockEnabledProvider);
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        final notifier = container.read(appLockEnabledProvider.notifier);
        await notifier.set(false);

        expect(container.read(appLockEnabledProvider), false);
        verify(
          () => mockSettingsRepo.setRaw(
            SettingsKeys.appLockEnabled,
            'false',
          ),
        ).called(1);
      });
    });

    group('authenticatedProvider', () {
      test('defaults to false', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(authenticatedProvider), false);
      });

      test('can be toggled to true', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(authenticatedProvider.notifier).state = true;

        expect(container.read(authenticatedProvider), true);
      });

      test('can be toggled back to false', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(authenticatedProvider.notifier).state = true;
        container.read(authenticatedProvider.notifier).state = false;

        expect(container.read(authenticatedProvider), false);
      });
    });

    group('canAuthenticateProvider', () {
      test('returns true when device is supported and has biometrics', () async {
        when(() => mockLocalAuth.isDeviceSupported())
            .thenAnswer((_) async => true);
        when(() => mockLocalAuth.canCheckBiometrics)
            .thenAnswer((_) async => true);

        final container = ProviderContainer(
          overrides: [
            localAuthProvider.overrideWithValue(mockLocalAuth),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(canAuthenticateProvider.future);

        expect(result, true);
      });

      test('returns true when device is supported but biometrics unavailable',
          () async {
        when(() => mockLocalAuth.isDeviceSupported())
            .thenAnswer((_) async => true);
        when(() => mockLocalAuth.canCheckBiometrics)
            .thenAnswer((_) async => false);
        when(() => mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.strong]);

        final container = ProviderContainer(
          overrides: [
            localAuthProvider.overrideWithValue(mockLocalAuth),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(canAuthenticateProvider.future);

        expect(result, true);
      });

      test('returns false when device is not supported', () async {
        when(() => mockLocalAuth.isDeviceSupported())
            .thenAnswer((_) async => false);

        final container = ProviderContainer(
          overrides: [
            localAuthProvider.overrideWithValue(mockLocalAuth),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(canAuthenticateProvider.future);

        expect(result, false);
      });

      test('returns false when both canCheckBiometrics and getAvailableBiometrics'
          ' are empty', () async {
        when(() => mockLocalAuth.isDeviceSupported())
            .thenAnswer((_) async => true);
        when(() => mockLocalAuth.canCheckBiometrics)
            .thenAnswer((_) async => false);
        when(() => mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => []);

        final container = ProviderContainer(
          overrides: [
            localAuthProvider.overrideWithValue(mockLocalAuth),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(canAuthenticateProvider.future);

        expect(result, false);
      });

      test('returns false on local_auth exception', () async {
        when(() => mockLocalAuth.isDeviceSupported())
            .thenThrow(Exception('Auth service unavailable'));

        final container = ProviderContainer(
          overrides: [
            localAuthProvider.overrideWithValue(mockLocalAuth),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(canAuthenticateProvider.future);

        expect(result, false);
      });
    });

    group('localAuthProvider', () {
      test('provides a LocalAuthentication instance', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final instance = container.read(localAuthProvider);

        expect(instance, isA<LocalAuthentication>());
      });
    });
  });
}
