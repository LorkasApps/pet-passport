import 'package:flutter/material.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../auth/application/auth_providers.dart';
import '../../households/application/households_providers.dart';
import '../../households/domain/household.dart';
import '../../security/application/app_lock_providers.dart';
import '../application/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final leadDays = ref.watch(reminderLeadControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(text: l.settingsAppearance),
          ListTile(
            title: Text(l.settingsThemeMode),
            subtitle: Text(_themeLabel(l, themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTheme(context, ref, l, themeMode),
          ),
          ListTile(
            title: Text(l.settingsLanguage),
            subtitle: Text(_localeLabel(l, locale)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLocale(context, ref, l, locale),
          ),
          _SectionHeader(text: l.settingsReminders),
          ListTile(
            title: Text(l.settingsReminderLead),
            subtitle: Text(l.settingsReminderLeadValue(leadDays)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLead(context, ref, l, leadDays),
          ),
          _SectionHeader(text: l.settingsSecurity),
          _AppLockTile(),
          if (SupabaseConfig.isConfigured) ...[
            _SectionHeader(text: l.settingsCloudSection),
            const _CloudTile(),
            const _HouseholdsSection(),
          ],
        ],
      ),
    );
  }

  Future<void> _pickLead(
    BuildContext context,
    WidgetRef ref,
    AppL10n l,
    int current,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<int>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final days in ReminderLeadController.options)
                RadioListTile<int>(
                  value: days,
                  title: Text(l.settingsReminderLeadValue(days)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      await ref.read(reminderLeadControllerProvider.notifier).set(picked);
    }
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    AppL10n l,
    ThemeMode current,
  ) async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  value: mode,
                  title: Text(_themeLabel(l, mode)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      await ref.read(themeModeProvider.notifier).set(picked);
    }
  }

  Future<void> _pickLocale(
    BuildContext context,
    WidgetRef ref,
    AppL10n l,
    Locale? current,
  ) async {
    final options = <Locale?>[null, const Locale('de'), const Locale('en')];
    final picked = await showModalBottomSheet<Locale?>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<Locale?>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final loc in options)
                RadioListTile<Locale?>(
                  value: loc,
                  title: Text(_localeLabel(l, loc)),
                ),
            ],
          ),
        ),
      ),
    );
    // A null selection means "system default". We need to differentiate
    // "user cancelled" from "user picked null" — bottom sheet returning
    // null via dismiss can't be distinguished, so we accept null both ways.
    // Practically: dismiss preserves current, tap-null resets to system.
    if (picked == null && current == null) return;
    await ref.read(localeProvider.notifier).set(picked);
  }

  String _themeLabel(AppL10n l, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => l.settingsThemeSystem,
      ThemeMode.light => l.settingsThemeLight,
      ThemeMode.dark => l.settingsThemeDark,
    };
  }

  String _localeLabel(AppL10n l, Locale? locale) {
    if (locale == null) return l.settingsLanguageSystem;
    return switch (locale.languageCode) {
      'de' => l.settingsLanguageGerman,
      'en' => l.settingsLanguageEnglish,
      _ => locale.languageCode,
    };
  }
}

class _HouseholdsSection extends ConsumerWidget {
  const _HouseholdsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final signedIn = ref.watch(isSignedInProvider);
    if (!signedIn) return const SizedBox.shrink();
    final async = ref.watch(myHouseholdsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(text: l.householdsSection),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$e'),
          ),
          data: (households) {
            if (households.isEmpty) {
              return ListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text(l.householdsEmpty),
              );
            }
            return Column(
              children: [
                for (final h in households) _HouseholdTile(h: h),
              ],
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(l.householdsCreate),
          onTap: () => _promptCreate(context, ref, l),
        ),
        ListTile(
          leading: const Icon(Icons.login),
          title: Text(l.joinAction),
          onTap: () => context.push('/join'),
        ),
      ],
    );
  }

  Future<void> _promptCreate(
    BuildContext context,
    WidgetRef ref,
    AppL10n l,
  ) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.householdsCreate),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: l.householdsCreateHint),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l.actionSave),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    await ref.read(myHouseholdsProvider.notifier).create(name);
  }
}

class _HouseholdTile extends StatelessWidget {
  const _HouseholdTile({required this.h});

  final Household h;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(h.isOwner ? Icons.workspace_premium : Icons.home_outlined,
            color: scheme.onSecondaryContainer),
      ),
      title: Text(h.name),
      subtitle: Text(
        '${h.isOwner ? l.householdsRoleOwner : l.householdsRoleMember}'
        ' · ${l.householdsMemberCount(h.memberCount)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/households/${h.id}'),
    );
  }
}

class _CloudTile extends ConsumerWidget {
  const _CloudTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return ListTile(
        leading: const Icon(Icons.cloud_outlined),
        title: Text(l.settingsSignIn),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/auth/signin'),
      );
    }
    return ListTile(
      leading: const Icon(Icons.cloud_done_outlined),
      title: Text(l.settingsSignedInAs(user.email ?? '')),
      subtitle: Text(l.settingsSignOut,
          style: TextStyle(color: Theme.of(context).colorScheme.primary)),
      onTap: () async {
        await ref.read(authRepositoryProvider).signOut();
      },
    );
  }
}

class _AppLockTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final enabled = ref.watch(appLockEnabledProvider);
    final canAsync = ref.watch(canAuthenticateProvider);
    final canAuth = canAsync.valueOrNull ?? false;
    return SwitchListTile.adaptive(
      title: Text(l.settingsAppLock),
      subtitle: Text(
        canAuth ? l.settingsAppLockHelp : l.settingsAppLockUnavailable,
      ),
      value: enabled && canAuth,
      onChanged: !canAuth
          ? null
          : (v) async {
              await ref.read(appLockEnabledProvider.notifier).set(v);
              if (v) {
                // Turning it on shouldn't immediately lock the current
                // session — the user is already in front of the phone.
                ref.read(authenticatedProvider.notifier).state = true;
              }
            },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
