import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/app/theme.dart';
import 'package:pepoconnect/dev/fakes.dart';
import 'package:pepoconnect/features/settings/sections/notifications_section.dart';
import 'package:pepoconnect/features/settings/update_checker.dart';
import 'package:pepoconnect/features/updates/update_controller.dart';
import 'package:pepoconnect/features/updates/update_controls.dart';
import 'package:pepoconnect/features/updates/update_installer.dart';
import 'package:pepoconnect/features/updates/update_prompt.dart';
import 'package:pepoconnect/features/updates/update_providers.dart';
import 'package:pepoconnect/shared/i18n/l10n.dart';
import 'package:pepoconnect/shared/motion/motion_scope.dart';
import 'package:pepoconnect/shared/widgets/pepo_checkbox.dart';
import 'package:pepoconnect/shared/widgets/pepo_dialog.dart';
import 'package:pepoconnect/shared/widgets/toggle_switch.dart';
import 'package:pepoconnect/state/app_settings.dart';

class _Store implements UpdateStore {
  String? value;
  Future<void>? delay;
  @override
  String? read() => value;
  @override
  Future<void> write(String value) async {
    await delay;
    this.value = value;
  }
}

class _Installer extends UpdateInstaller {
  late Completer<UpdateInstallOutcome> pending;
  int calls = 0;
  @override
  Future<UpdateSupport> support(UpdateCheckResult release) async => UpdateSupport.android;
  @override
  Future<UpdateInstallOutcome> install(
    UpdateCheckResult release, {
    required void Function(UpdateProgress) onProgress,
    required Future<void> Function() beforeRestart,
  }) {
    calls++;
    pending = Completer<UpdateInstallOutcome>();
    onProgress(
      const UpdateProgress(phase: UpdateInstallPhase.downloading, received: 25, total: 100),
    );
    return pending.future;
  }

  @override
  void cancel() {
    if (!pending.isCompleted) {
      pending.completeError(const UpdateInstallException('cancelled', 'cancelled'));
    }
  }

  @override
  void dispose() {}
}

void main() {
  late _Installer installer;
  late UpdateController controller;
  late FakeSettingsNotifier settings;
  late GlobalKey<NavigatorState> navigator;

  Future<void> pump(
    WidgetTester tester, {
    bool prompt = false,
    Widget? child,
    bool foreground = true,
    UpdateStore? store,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    controller = UpdateController(
      currentVersion: '0.3.0',
      store: store ?? _Store(),
      installer: installer,
      check: () async => UpdateCheckResult.fromJson({'tag_name': 'v0.4.0'}, current: '0.3.0'),
      beforeRestart: () async {},
    );
    navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateControllerProvider.overrideWithValue(controller),
          updateCanInstallProvider.overrideWithValue(true),
          updateForegroundProvider.overrideWithValue(() async => foreground),
          settingsProvider.overrideWith(() => settings),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: buildLightTheme(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, widget) => MotionScope(
            enabled: false,
            child: prompt ? UpdatePromptHost(navigatorKey: navigator, child: widget!) : widget!,
          ),
          home: Scaffold(body: SingleChildScrollView(child: child ?? const UpdateControls())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    installer = _Installer();
    settings = FakeSettingsNotifier(const AppSettings(onboarded: true, animations: false));
  });
  tearDown(() => controller.dispose());

  testWidgets('manual check offers installation, progress and cancellation', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Comprobar actualizaciones').last);
    await tester.pumpAndSettle();
    expect(find.text('Hay una versión nueva: 0.4.0'), findsOneWidget);
    await tester.tap(find.text('Actualizar'));
    await tester.pump();
    expect(installer.calls, 1);
    expect(find.textContaining('25 %'), findsOneWidget);
    await tester.tap(find.text('Cancelar descarga'));
    await tester.pumpAndSettle();
    expect(find.text('Actualizar'), findsOneWidget);
  });

  testWidgets('automatic offer can disable future foreground notifications', (tester) async {
    await pump(tester, prompt: true, child: const Text('app'));
    expect(find.byType(PepoDialog), findsOneWidget);
    await tester.tap(find.byType(PepoCheckbox));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(UpdatePromptHost)));
    expect(container.read(settingsProvider).updateNotifications, isFalse);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(find.byType(PepoDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a hidden app checks but never steals focus with an offer', (tester) async {
    await pump(tester, prompt: true, foreground: false, child: const Text('app'));
    expect(controller.state.release?.latest, '0.4.0');
    expect(find.byType(PepoDialog), findsNothing);
    expect(controller.shouldPrompt(notificationsEnabled: true), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opt-out keeps checking without showing the foreground offer', (tester) async {
    settings = FakeSettingsNotifier(const AppSettings(onboarded: true, updateNotifications: false));
    await pump(tester, prompt: true, child: const Text('app'));
    expect(controller.state.release?.latest, '0.4.0');
    expect(find.byType(PepoDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('slow preferences cannot delay the foreground dialog push', (tester) async {
    final writing = Completer<void>();
    final store = _Store()..delay = writing.future;
    await pump(tester, prompt: true, child: const Text('app'), store: store);
    expect(find.byType(PepoDialog), findsOneWidget);
    writing.complete();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('update offer fits a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, prompt: true, child: const Text('app'));
    expect(find.byType(PepoDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('notification settings have an independent update toggle', (tester) async {
    await pump(tester, child: const NotificationsSection());
    final toggle = find.descendant(
      of: find
          .ancestor(of: find.text('Avisos de actualizaciones'), matching: find.byType(Row))
          .first,
      matching: find.byType(ToggleSwitch),
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(NotificationsSection)));
    expect(container.read(settingsProvider).updateNotifications, isFalse);
    expect(container.read(settingsProvider).notifications, isTrue);
  });
}
