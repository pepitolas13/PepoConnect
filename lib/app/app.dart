import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import '../platform/open_helper.dart';
import '../shared/motion/motion_scope.dart';
import '../shared/motion/toast.dart';
import '../state/app_settings.dart';
import '../state/engine_providers.dart';
import 'app_services.dart';
import 'router.dart';
import 'shell/app_shell.dart';
import 'shell/window_effects.dart';
import 'theme.dart';
import '../features/activity/activity_panel_content.dart';

/// Root widget: theme, locale, motion scope, toasts and the router.
class PepoApp extends ConsumerStatefulWidget {
  const PepoApp({super.key});

  @override
  ConsumerState<PepoApp> createState() => _PepoAppState();
}

class _PepoAppState extends ConsumerState<PepoApp> {
  late final GoRouter _router;
  AppServices? _services;
  final _refresh = _RouterRefresh();

  @override
  void initState() {
    super.initState();
    _router = buildRouter(
      actions: ShellActions(
        onOpenDownloads: (_) => OpenHelper.openFolder(ref.read(engineProvider).config.downloadRoot),
        onRenamePc: (_, name) => ref.read(engineProvider).setDeviceName(name),
        onClearActivity: (_) => ref.read(activityProvider.notifier).clear(),
        onRefresh: (_) => ref.read(devicesProvider.notifier).reconnect(),
        activityPanelBuilder: (_) => const ActivityPanelContent(),
      ),
      initialLocation: _initialLocation(),
      redirect: _redirect,
      refreshListenable: _refresh,
    );
    ref.listenManual(settingsProvider, (_, _) => _refresh.notify());
    ref.listenManual(devicesProvider, (_, _) => _refresh.notify());
    WidgetsBinding.instance.addPostFrameCallback((_) => _startServices());
  }

  String _initialLocation() {
    final settings = ref.read(settingsProvider);
    return settings.onboarded ? AppRoutes.transfers : AppRoutes.onboarding;
  }

  /// First run: stay in onboarding/pairing until a device is paired (or the
  /// user chose to skip).
  String? _redirect(BuildContext context, GoRouterState state) {
    final settings = ref.read(settingsProvider);
    final devices = ref.read(devicesProvider);
    final loc = state.matchedLocation;
    final inOnboarding = loc == AppRoutes.onboarding || loc == AppRoutes.pair;
    if (!settings.onboarded && devices.isEmpty && !inOnboarding) return AppRoutes.onboarding;
    return null;
  }

  Future<void> _startServices() async {
    if (!mounted) return;
    final services = AppServices(ProviderScope.containerOf(context), _router);
    _services = services;
    await services.start();
  }

  @override
  void dispose() {
    _services?.dispose();
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final locale = settings.locale == 'system' ? null : Locale(settings.locale);
    return ValueListenableBuilder<bool>(
      valueListenable: windowEffectsActive,
      builder: (context, mica, _) => MaterialApp.router(
        title: 'PepoConnect',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        theme: buildLightTheme(transparentBackground: mica),
        darkTheme: buildDarkTheme(transparentBackground: mica),
        themeMode: themeModeOf(settings.themeMode),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          _services?.attachLocalizations(AppLocalizations.of(context));
          return MotionScope(
            enabled: settings.animations,
            child: ToastHost(
              service: ref.read(toastServiceProvider),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
