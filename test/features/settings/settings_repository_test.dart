import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/settings/data/settings_repository.dart';

import '../../helpers/database_helper.dart';

void main() {
  group('SettingsRepository', () {
    late SettingsRepository repo;

    setUp(() {
      final db = newInMemoryDatabase();
      repo = SettingsRepository(db.settingsDao);
    });

    test('getRaw returns null when key is not set', () async {
      final value = await repo.getRaw('non_existent_key');
      expect(value, isNull);
    });

    test('setRaw stores a value and getRaw retrieves it', () async {
      await repo.setRaw('test_key', 'test_value');
      final value = await repo.getRaw('test_key');
      expect(value, equals('test_value'));
    });

    test('setRaw overwrites an existing value', () async {
      await repo.setRaw('test_key', 'initial_value');
      await repo.setRaw('test_key', 'updated_value');
      final value = await repo.getRaw('test_key');
      expect(value, equals('updated_value'));
    });

    test('remove deletes a stored key', () async {
      await repo.setRaw('test_key', 'test_value');
      await repo.remove('test_key');
      final value = await repo.getRaw('test_key');
      expect(value, isNull);
    });

    test('setRaw stores multiple different keys independently', () async {
      await repo.setRaw('key1', 'value1');
      await repo.setRaw('key2', 'value2');
      await repo.setRaw('key3', 'value3');

      expect(await repo.getRaw('key1'), equals('value1'));
      expect(await repo.getRaw('key2'), equals('value2'));
      expect(await repo.getRaw('key3'), equals('value3'));
    });

    test('watchRaw emits current value on subscription', () async {
      await repo.setRaw('watch_key', 'initial_value');

      final stream = repo.watchRaw('watch_key');
      expect(stream, emits(equals('initial_value')));
    });

    test('watchRaw emits null when key does not exist', () async {
      final stream = repo.watchRaw('non_existent_key');
      expect(stream, emits(isNull));
    });

    test('watchRaw emits new value when key is updated', () async {
      await repo.setRaw('watch_key', 'initial_value');

      final stream = repo.watchRaw('watch_key');
      final values = <String?>[];

      final subscription = stream.listen(values.add);

      await Future.delayed(Duration(milliseconds: 100));
      await repo.setRaw('watch_key', 'updated_value');
      await Future.delayed(Duration(milliseconds: 100));

      addTearDown(subscription.cancel);

      expect(values, containsAll(['initial_value', 'updated_value']));
    });

    test('watchRaw emits null when key is removed', () async {
      await repo.setRaw('watch_key', 'value');

      final stream = repo.watchRaw('watch_key');
      final values = <String?>[];

      final subscription = stream.listen(values.add);

      await Future.delayed(Duration(milliseconds: 100));
      await repo.remove('watch_key');
      await Future.delayed(Duration(milliseconds: 100));

      addTearDown(subscription.cancel);

      expect(values, contains(isNull));
    });

    test('SettingsKeys constants are defined correctly', () {
      expect(SettingsKeys.themeMode, equals('theme_mode'));
      expect(SettingsKeys.locale, equals('locale'));
      expect(SettingsKeys.onboardingCompleted, equals('onboarding_completed'));
      expect(SettingsKeys.appLockEnabled, equals('app_lock_enabled'));
      expect(SettingsKeys.currentPetUuid, equals('current_pet_uuid'));
      expect(SettingsKeys.reminderLeadDays, equals('reminder_lead_days'));
    });

    test('can store settings using SettingsKeys constants', () async {
      await repo.setRaw(SettingsKeys.locale, 'en');
      await repo.setRaw(SettingsKeys.themeMode, 'dark');
      await repo.setRaw(SettingsKeys.reminderLeadDays, '7');
      await repo.setRaw(SettingsKeys.onboardingCompleted, 'true');

      expect(await repo.getRaw(SettingsKeys.locale), equals('en'));
      expect(await repo.getRaw(SettingsKeys.themeMode), equals('dark'));
      expect(await repo.getRaw(SettingsKeys.reminderLeadDays), equals('7'));
      expect(await repo.getRaw(SettingsKeys.onboardingCompleted), equals('true'));
    });
  });
}
