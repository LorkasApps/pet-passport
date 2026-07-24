import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../features/auth/application/profile_providers.dart';
import '../features/auth/presentation/auth_callback_screen.dart';
import '../features/auth/presentation/display_name_screen.dart';
import '../features/auth/presentation/privacy_notice_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/households/presentation/household_detail_screen.dart';
import '../features/households/presentation/invite_screen.dart';
import '../features/households/presentation/join_household_screen.dart';
import '../features/households/presentation/qr_scan_screen.dart';
import '../features/appointments/presentation/appointment_detail_screen.dart';
import '../features/appointments/presentation/appointment_edit_screen.dart';
import '../features/appointments/presentation/appointments_list_screen.dart';
import '../features/appointments/presentation/termine_screen.dart';
import '../features/charts/presentation/weight_chart_screen.dart';
import '../features/diet/presentation/diet_list_screen.dart';
import '../features/diet/presentation/food_edit_screen.dart';
import '../features/medications/presentation/medication_detail_screen.dart';
import '../features/medications/presentation/medication_edit_screen.dart';
import '../features/medications/presentation/medication_intake_history_screen.dart';
import '../features/medications/presentation/medications_list_screen.dart';
import '../features/dashboard/presentation/overview_screen.dart';
import '../features/emergency/presentation/emergency_screen.dart';
import '../features/export_import/presentation/export_screen.dart';
import '../features/insurances/presentation/insurance_detail_screen.dart';
import '../features/insurances/presentation/insurance_edit_screen.dart';
import '../features/insurances/presentation/insurances_list_screen.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/onboarding/presentation/onboarding_wizard_screen.dart';
import '../features/pdf/presentation/pdf_menu_screen.dart';
import '../features/pets/application/current_pet_provider.dart';
import '../features/pets/presentation/passport_screen.dart';
import '../features/pets/presentation/pet_edit_screen.dart';
import '../features/pets/presentation/pet_management_screen.dart';
import '../features/pets/presentation/pet_switcher_sheet.dart';
import '../features/pets/presentation/widgets/pet_avatar.dart';
import '../features/protocol/domain/event_enums.dart';
import '../features/protocol/presentation/alltag_screen.dart';
import '../features/protocol/presentation/event_detail_screen.dart';
import '../features/protocol/presentation/event_edit_screen.dart';
import '../features/settings/application/settings_providers.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/sync/presentation/sync_status_badge.dart';
import '../features/timeline/presentation/timeline_screen.dart';
import '../features/vaccinations/presentation/vaccination_detail_screen.dart';
import '../features/vaccinations/presentation/vaccination_edit_screen.dart';
import '../features/vaccinations/presentation/vaccinations_list_screen.dart';
import '../features/contacts/presentation/contact_detail_screen.dart';
import '../features/contacts/presentation/contact_edit_screen.dart';
import '../features/contacts/presentation/contacts_list_screen.dart';
import '../features/documents/presentation/documents_list_screen.dart';
import '../features/vets/presentation/vet_detail_screen.dart';
import '../features/vets/presentation/vet_edit_screen.dart';
import '../features/vets/presentation/vets_list_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellHomeKey = GlobalKey<NavigatorState>();
final _shellTermineKey = GlobalKey<NavigatorState>();
final _shellAlltagKey = GlobalKey<NavigatorState>();
final _shellMoreKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Backed by a synchronous StateNotifier so a UI-triggered
  // `markCompleted` bumps `state` in the same microtask as the follow-up
  // `context.go(...)`, and the redirect logic below sees the new value.
  final onboardingListenable = ValueNotifier<bool>(
    ref.read(onboardingControllerProvider),
  );
  ref.listen<bool>(onboardingControllerProvider, (_, next) {
    onboardingListenable.value = next;
  });
  ref.onDispose(onboardingListenable.dispose);

  // Second listenable for the display-name gate. Fires when a user
  // signs in without a profile row (first-cloud-login) or when the row
  // finally appears (after saveDisplayName). Combined with the
  // onboarding listenable so a change on either kicks the redirect.
  final needsDisplayNameListenable =
      ValueNotifier<bool>(ref.read(needsDisplayNameProvider));
  ref.listen<bool>(needsDisplayNameProvider, (_, next) {
    needsDisplayNameListenable.value = next;
  });
  ref.onDispose(needsDisplayNameListenable.dispose);

  final refresh = Listenable.merge(
    <Listenable>[onboardingListenable, needsDisplayNameListenable],
  );

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final raw = state.uri.toString();

      // Magic-link deep link comes in with the full custom scheme URI:
      //   petpassport://auth/callback?code=...
      // GoRouter can't match that against a pathed route, so it errors
      // out ("no routes for location …"). Normalise to the pathed route
      // and let AuthCallbackScreen wait for the SDK's parallel PKCE
      // exchange to finish.
      final isAuthCallback = raw.contains('auth/callback');
      if (isAuthCallback && loc != '/auth/callback') {
        return '/auth/callback';
      }
      if (loc == '/auth/callback') {
        // Once we're on the pathed route the auth callback runs its
        // course inside the screen — skip the onboarding gate below so
        // an un-onboarded new install doesn't bounce out of the flow.
        return null;
      }

      // Invite deep link: petpassport://invite/<token>. Same normalise
      // trick as above — pluck the token out of the URI and hand it to
      // the join screen as a query param.
      if (raw.contains('://invite/') || raw.contains('/invite/')) {
        final uri = state.uri;
        String? token;
        if (uri.host == 'invite' && uri.pathSegments.isNotEmpty) {
          token = uri.pathSegments.first;
        } else {
          final idx = uri.pathSegments.indexOf('invite');
          if (idx >= 0 && idx + 1 < uri.pathSegments.length) {
            token = uri.pathSegments[idx + 1];
          }
        }
        if (token != null && token.isNotEmpty && loc != '/join') {
          return '/join?token=$token';
        }
      }
      if (loc == '/join' || loc == '/join/scan') {
        return null;
      }

      // Signed in but no profile row yet → force display-name screen.
      // Sign-in / sign-out surfaces are exempt so the user can bail out
      // or complete an interrupted auth flow.
      if (needsDisplayNameListenable.value &&
          loc != '/profile/setup' &&
          loc != '/privacy' &&
          !loc.startsWith('/auth/')) {
        return '/profile/setup';
      }

      final onboardingCompleted = onboardingListenable.value;
      if (!onboardingCompleted && loc != '/onboarding') {
        return '/onboarding';
      }
      if (onboardingCompleted && loc == '/onboarding') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const OnboardingWizardScreen(),
      ),
      GoRoute(
        path: '/auth/signin',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth/callback',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AuthCallbackScreen(),
      ),
      GoRoute(
        path: '/profile/setup',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const DisplayNameScreen(),
      ),
      GoRoute(
        path: '/privacy',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const PrivacyNoticeScreen(),
      ),
      GoRoute(
        path: '/households/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => HouseholdDetailScreen(
          householdId: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/households/:id/invite',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => InviteScreen(
          householdId: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/join',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => JoinHouseholdScreen(
          initialToken: s.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: '/join/scan',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const QrScanScreen(),
      ),
      GoRoute(
        path: '/pets/new',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const PetEditScreen(),
      ),
      GoRoute(
        path: '/pets/:id/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => PetEditScreen(petUuid: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/pets',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const PetManagementScreen(),
      ),
      GoRoute(
        path: '/vets',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const VetsListScreen(),
      ),
      GoRoute(
        path: '/pets/:petId/vets/new',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => VetEditScreen(
          petUuid: s.pathParameters['petId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/vets/:vetId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => VetDetailScreen(
          petUuid: s.pathParameters['petId']!,
          vetUuid: s.pathParameters['vetId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/vets/:vetId/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => VetEditScreen(
          petUuid: s.pathParameters['petId']!,
          vetUuid: s.pathParameters['vetId'],
        ),
      ),
      GoRoute(
        path: '/contacts',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ContactsListScreen(),
      ),
      GoRoute(
        path: '/pets/:petId/contacts/new',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ContactEditScreen(
          petUuid: s.pathParameters['petId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/contacts/:contactId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ContactDetailScreen(
          petUuid: s.pathParameters['petId']!,
          contactUuid: s.pathParameters['contactId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/contacts/:contactId/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ContactEditScreen(
          petUuid: s.pathParameters['petId']!,
          contactUuid: s.pathParameters['contactId'],
        ),
      ),
      GoRoute(
        path: '/documents',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const DocumentsListScreen(),
      ),
      GoRoute(
        path: '/insurances',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const InsurancesListScreen(),
      ),
      GoRoute(
        path: '/vaccinations',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const VaccinationsListScreen(),
      ),
      GoRoute(
        path: '/appointments',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AppointmentsListScreen(),
      ),
      GoRoute(
        path: '/pets/:petId/appointments/new',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => AppointmentEditScreen(
          petUuid: s.pathParameters['petId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/appointments/:apptId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => AppointmentDetailScreen(
          petUuid: s.pathParameters['petId']!,
          appointmentUuid: s.pathParameters['apptId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/appointments/:apptId/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => AppointmentEditScreen(
          petUuid: s.pathParameters['petId']!,
          appointmentUuid: s.pathParameters['apptId'],
        ),
      ),
      GoRoute(
        path: '/medications',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const MedicationsListScreen(),
      ),
      GoRoute(
        path: '/pets/:petId/medications/new',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => MedicationEditScreen(
          petUuid: s.pathParameters['petId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/medications/:medId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => MedicationDetailScreen(
          petUuid: s.pathParameters['petId']!,
          medicationUuid: s.pathParameters['medId']!,
          autoLog: s.uri.queryParameters['log'] == '1',
        ),
      ),
      GoRoute(
        path: '/pets/:petId/medications/:medId/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => MedicationEditScreen(
          petUuid: s.pathParameters['petId']!,
          medicationUuid: s.pathParameters['medId'],
        ),
      ),
      GoRoute(
        path: '/pets/:petId/medications/:medId/intakes',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => MedicationIntakeHistoryScreen(
          petUuid: s.pathParameters['petId']!,
          medicationUuid: s.pathParameters['medId']!,
        ),
      ),
      GoRoute(
        path: '/diet',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const DietListScreen(),
      ),
      GoRoute(
        path: '/pets/:petId/diet/new',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => FoodEditScreen(
          petUuid: s.pathParameters['petId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/diet/:foodId/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => FoodEditScreen(
          petUuid: s.pathParameters['petId']!,
          foodUuid: s.pathParameters['foodId'],
        ),
      ),
      GoRoute(
        path: '/pets/:petId/charts/weight',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => WeightChartScreen(
          petUuid: s.pathParameters['petId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/vaccinations/new',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => VaccinationEditScreen(
          petUuid: s.pathParameters['petId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/vaccinations/:vacId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => VaccinationDetailScreen(
          petUuid: s.pathParameters['petId']!,
          vaccinationUuid: s.pathParameters['vacId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/vaccinations/:vacId/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => VaccinationEditScreen(
          petUuid: s.pathParameters['petId']!,
          vaccinationUuid: s.pathParameters['vacId'],
        ),
      ),
      GoRoute(
        path: '/pets/:petId/insurances/new',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => InsuranceEditScreen(
          petUuid: s.pathParameters['petId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/insurances/:insId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => InsuranceDetailScreen(
          petUuid: s.pathParameters['petId']!,
          insuranceUuid: s.pathParameters['insId']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/insurances/:insId/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => InsuranceEditScreen(
          petUuid: s.pathParameters['petId']!,
          insuranceUuid: s.pathParameters['insId'],
        ),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/emergency',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const EmergencyScreen(),
      ),
      GoRoute(
        path: '/export',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ExportScreen(),
      ),
      GoRoute(
        path: '/timeline',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const TimelineScreen(),
      ),
      GoRoute(
        path: '/pdf',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const PdfMenuScreen(),
      ),
      GoRoute(
        path: '/passport',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const PassportScreen(),
      ),
      GoRoute(
        path: '/pets/:petId/events/new',
        parentNavigatorKey: _rootKey,
        builder: (_, s) {
          final typeName = s.uri.queryParameters['type'];
          final type = typeName == null
              ? null
              : EventType.values.firstWhere(
                  (t) => t.name == typeName,
                  orElse: () => EventType.generic,
                );
          return EventEditScreen(
            petUuid: s.pathParameters['petId']!,
            initialType: type,
          );
        },
      ),
      GoRoute(
        path: '/pets/:petId/events/:eventUuid',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => EventDetailScreen(
          petUuid: s.pathParameters['petId']!,
          eventUuid: s.pathParameters['eventUuid']!,
        ),
      ),
      GoRoute(
        path: '/pets/:petId/events/:eventUuid/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => EventEditScreen(
          petUuid: s.pathParameters['petId']!,
          eventUuid: s.pathParameters['eventUuid'],
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellHomeKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const OverviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellTermineKey,
            routes: [
              GoRoute(
                path: '/termine',
                builder: (_, _) => const TermineScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellAlltagKey,
            routes: [
              GoRoute(
                path: '/alltag',
                builder: (_, _) => const AlltagScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellMoreKey,
            routes: [
              GoRoute(
                path: '/mehr',
                builder: (_, _) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _MainShell extends ConsumerWidget {
  const _MainShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(
        actions: const [SyncStatusBadge()],
        title: petAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (pet) {
            if (pet == null) return Text(l.appTitle);
            return InkWell(
              onTap: () => showPetSwitcherSheet(context),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PetAvatar(pet: pet, radius: 18),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        pet.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, size: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_outlined),
            selectedIcon: const Icon(Icons.event),
            label: l.navTermine,
          ),
          NavigationDestination(
            icon: const Icon(Icons.article_outlined),
            selectedIcon: const Icon(Icons.article),
            label: l.navAlltag,
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            selectedIcon: const Icon(Icons.more_horiz),
            label: l.navMore,
          ),
        ],
      ),
    );
  }
}
