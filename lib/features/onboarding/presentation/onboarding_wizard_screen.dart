import 'package:flutter/material.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../auth/application/auth_providers.dart';
import '../../settings/application/settings_providers.dart';

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState
    extends ConsumerState<OnboardingWizardScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finishAndGoToAddPet() async {
    await ref.read(onboardingControllerProvider.notifier).markCompleted();
    if (!mounted) return;
    context.go('/pets/new');
  }

  Future<void> _finishAndSkip() async {
    await ref.read(onboardingControllerProvider.notifier).markCompleted();
    if (!mounted) return;
    // Route to /home instead of /pets — /pets is a full-screen route
    // outside the shell (parentNavigatorKey: _rootKey), which hides
    // the bottom nav and leaves the user stranded with no way to
    // reach Settings / More. /home lives inside the shell, so the
    // empty-overview state renders alongside the nav bar.
    context.go('/home');
  }

  Future<void> _finishAndJoin() async {
    await ref.read(onboardingControllerProvider.notifier).markCompleted();
    if (!mounted) return;
    // If cloud isn't compiled in there's nowhere to send the user;
    // fall back to the shell so they at least aren't stuck.
    if (!SupabaseConfig.isConfigured) {
      context.go('/home');
      return;
    }
    // Signed in? go straight to the join screen. Otherwise route
    // through sign-in — the router will bounce back to /home after
    // display-name onboarding completes, and the user reaches join
    // via Settings → Cloud sync.
    final signedIn = ref.read(isSignedInProvider);
    context.go(signedIn ? '/join' : '/auth/signin');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _Page(
                    icon: Icons.pets,
                    title: l.onboardingWelcomeTitle,
                    body: l.onboardingWelcomeBody,
                  ),
                  _Page(
                    icon: Icons.add_circle_outline,
                    title: l.onboardingAddFirstPetTitle,
                    body: l.onboardingAddFirstPetBody,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            if (_page >= 1 && SupabaseConfig.isConfigured)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextButton.icon(
                  onPressed: _finishAndJoin,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(l.onboardingHaveInvite),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _finishAndSkip,
                    child: Text(l.actionSkip),
                  ),
                  _page < 1
                      ? FilledButton(
                          onPressed: () => _controller.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                          child: Text(l.actionNext),
                        )
                      : FilledButton.icon(
                          onPressed: _finishAndGoToAddPet,
                          icon: const Icon(Icons.add),
                          label: Text(l.actionAdd),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 32),
          Text(title,
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
