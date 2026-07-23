import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../application/auth_providers.dart';

/// Entry point for turning cloud features on. Reachable from Settings.
///
/// Two states:
///   1. Idle — email input + "Magic Link senden" button
///   2. Waiting — "Mail geschickt, öffne den Link auf deinem Gerät"
///
/// The auth callback (`petpassport://auth/callback`) is handled by the
/// Supabase SDK's built-in deep-link observer; we don't need our own
/// callback screen. Once the session flips to signed-in, the app root
/// will react to the auth-state stream and navigate onwards.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  String? _error;
  bool _linkSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailCtrl.text.trim();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendMagicLink(email);
      if (!mounted) return;
      setState(() => _linkSent = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.signInTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _linkSent ? _buildWaiting(l) : _buildForm(l),
      ),
    );
  }

  Widget _buildForm(AppL10n l) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.signInHeadline, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            l.signInBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: l.signInEmailLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty) return l.validationRequired;
              // Cheap gate: SDK does the real validation. Just catch
              // obviously-not-an-email so the user gets fast feedback.
              if (!s.contains('@') || !s.contains('.')) {
                return l.signInEmailInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(l.signInSendAction),
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
          const Spacer(),
          TextButton(
            onPressed: () => context.pop(),
            child: Text(l.signInSkipAction),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting(AppL10n l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined,
            size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(l.signInWaitingHeadline,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          l.signInWaitingBody(_emailCtrl.text.trim()),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: () => setState(() => _linkSent = false),
          child: Text(l.signInWaitingBack),
        ),
      ],
    );
  }
}
