import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

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
import '../features/pets/application/current_pet_provider.dart';
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
import '../features/vaccinations/presentation/vaccination_detail_screen.dart';
import '../features/vaccinations/presentation/vaccination_edit_screen.dart';
import '../features/vaccinations/presentation/vaccinations_list_screen.dart';
import '../features/vets/presentation/vet_detail_screen.dart';
import '../features/vets/presentation/vet_edit_screen.dart';
import '../features/vets/presentation/vets_list_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellHomeKey = GlobalKey<NavigatorState>();
final _shellTermineKey = GlobalKey<NavigatorState>();
final _shellAlltagKey = GlobalKey<NavigatorState>();
final _shellMoreKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final onboardingListenable = ValueNotifier<bool>(
    ref.read(onboardingCompletedProvider).valueOrNull ?? false,
  );
  ref.listen<AsyncValue<bool>>(onboardingCompletedProvider, (_, next) {
    onboardingListenable.value = next.valueOrNull ?? false;
  });
  ref.onDispose(onboardingListenable.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    refreshListenable: onboardingListenable,
    redirect: (context, state) {
      final loc = state.matchedLocation;
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
