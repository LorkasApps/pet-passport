import '../../../core/db/daos/settings_dao.dart';

class SettingsKeys {
  static const themeMode = 'theme_mode';
  static const locale = 'locale';
  static const onboardingCompleted = 'onboarding_completed';
  static const appLockEnabled = 'app_lock_enabled';
  static const currentPetUuid = 'current_pet_uuid';
  static const reminderLeadDays = 'reminder_lead_days';
  static const lastUsedHouseholdId = 'last_used_household_id';
  /// Comma-joined, ascending-sorted household ids the pull engine was
  /// scoped to on its last run. When the current membership set is a
  /// superset, cursors get wiped so the newly-visible rows land on the
  /// next pull.
  static const lastPullScopeHouseholds = 'last_pull_scope_households';
}

class SettingsRepository {
  SettingsRepository(this._dao);

  final SettingsDao _dao;

  Future<String?> getRaw(String key) => _dao.get(key);
  Stream<String?> watchRaw(String key) => _dao.watch(key);
  Future<void> setRaw(String key, String value) => _dao.set(key, value);
  Future<void> remove(String key) => _dao.remove(key);
}
