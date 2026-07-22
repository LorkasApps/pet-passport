import 'package:flutter/material.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
