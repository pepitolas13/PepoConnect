import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/activity_page.dart';
import '../features/gallery/gallery_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/pairing/pairing_page.dart';
import '../features/settings/settings_page.dart';
import '../features/transfers/transfers_page.dart';
import '../features/viewer/viewer_page.dart';
import '../shared/motion/branch_cross_fade.dart';
import '../shared/motion/fluent_page_transitions.dart';
import 'shell/app_shell.dart';

/// Route paths.
abstract final class AppRoutes {
  static const String transfers = '/transfers';
  static const String gallery = '/gallery';
  static const String activity = '/activity';
  static const String settings = '/settings';
  static const String onboarding = '/onboarding';
  static const String pair = '/pair';

  static String viewer(String deviceId, String id) =>
      '/viewer/${Uri.encodeComponent(deviceId)}/${Uri.encodeComponent(id)}';
}

/// The four shell branches plus the top-level routes. Sections dissolve into
/// each other ([BranchCrossFade]) instead of swapping in an IndexedStack.
List<RouteBase> appRoutes({
  ShellActions actions = const ShellActions(),
  GlobalKey<NavigatorState>? rootNavigatorKey,
}) => [
  StatefulShellRoute(
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell, actions: actions),
    navigatorContainerBuilder: BranchCrossFade.builder,
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.transfers,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const TransfersPage()),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.gallery,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const GalleryPage()),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.activity,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const ActivityPage()),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const SettingsPage()),
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: AppRoutes.onboarding,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) => FluentPage(key: state.pageKey, child: const OnboardingPage()),
  ),
  GoRoute(
    path: AppRoutes.pair,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) => FluentPage(key: state.pageKey, child: const PairingPage()),
  ),
  GoRoute(
    path: '/viewer/:deviceId/:id',
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) => FluentPage(
      key: state.pageKey,
      fullscreenDialog: true,
      child: ViewerPage(
        deviceId: state.pathParameters['deviceId'] ?? '',
        id: state.pathParameters['id'] ?? '',
      ),
    ),
  ),
];

/// Builds the app router. The orchestrator adds `redirect` (onboarding),
/// `refreshListenable` and the platform hooks in [actions].
GoRouter buildRouter({
  ShellActions actions = const ShellActions(),
  String initialLocation = AppRoutes.transfers,
  GlobalKey<NavigatorState>? navigatorKey,
  GoRouterRedirect? redirect,
  Listenable? refreshListenable,
  bool debugLogDiagnostics = false,
}) {
  final rootKey = navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    redirect: redirect,
    refreshListenable: refreshListenable,
    debugLogDiagnostics: debugLogDiagnostics,
    routes: appRoutes(actions: actions, rootNavigatorKey: rootKey),
  );
}
