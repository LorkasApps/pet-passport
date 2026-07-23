import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../households/application/households_providers.dart';
import '../../households/data/household_stamper.dart';
import '../../settings/application/settings_providers.dart';
import '../application/profile_providers.dart';

/// One-time forced screen the router shows after first sign-in until the
/// user has picked a display name. No skip / back button — leaving is
/// only possible by saving a valid name (or signing out via a separate
/// UI, but there's no direct route from here).
class DisplayNameScreen extends ConsumerStatefulWidget {
  const DisplayNameScreen({super.key});

  @override
  ConsumerState<DisplayNameScreen> createState() =>
      _DisplayNameScreenState();
}

class _DisplayNameScreenState extends ConsumerState<DisplayNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(myProfileProvider.notifier)
          .saveDisplayName(_ctrl.text);
      // First-run bootstrap: make sure the user has at least one
      // household so subsequent screens have something to bind data to.
      // Idempotent — a returning user with existing memberships is a
      // no-op here.
      if (!mounted) return;
      final l = AppL10n.of(context);
      final primaryId = await ref
          .read(householdsRepositoryProvider)
          .ensureDefault(l.householdsDefaultName);
      // Backfill pre-cloud local rows so they show up inside the newly
      // adopted household. No-op if the tables already carry an id from
      // an earlier sign-in on this device.
      await HouseholdStamper(ref.read(databaseProvider))
          .stampNullRows(primaryId);
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return PopScope(
      // Kein Zurück — Anzeigename ist Pflicht.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.displayNameTitle),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.displayNameHeadline,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l.displayNameBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l.displayNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                  maxLength: 60,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return l.validationRequired;
                    if (s.length < 2) return l.displayNameTooShort;
                    return null;
                  },
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(l.actionSave),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
