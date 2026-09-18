import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepo_core/pepo_core.dart' show MediaState;
import 'package:pepoconnect/app/router.dart';
import 'package:pepoconnect/app/shell/nav_rail.dart';
import 'package:pepoconnect/app/theme.dart';
import 'package:pepoconnect/dev/fakes.dart';
import 'package:pepoconnect/shared/i18n/l10n.dart';
import 'package:pepoconnect/shared/motion/motion_scope.dart';
import 'package:pepoconnect/state/app_settings.dart';

/// The whole shell with a fake gallery: one fresh photo and one already seen.
Future<void> pumpShell(WidgetTester tester) async {
  final now = DateTime.now();
  final entries = [
    fakeEntry(id: 'a', takenAt: now, state: MediaState.fresh),
    fakeEntry(id: 'b', takenAt: now.subtract(const Duration(hours: 1))),
  ];
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: fakeOverrides(
        settings: const AppSettings(animations: false),
        unread: 0,
        entries: entries,
      ),
      child: MaterialApp.router(
        routerConfig: buildRouter(),
        theme: buildLightTheme(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MotionScope(enabled: false, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openSection(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavRailItem, label));
  await tester.pumpAndSettle();
}

/// What the platform sends when the window is hidden, shown, etc.
Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) async {
  final data = const StringCodec().encodeMessage(state.toString());
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    data,
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new photo stays new while the gallery is on screen', (tester) async {
    await pumpShell(tester);
    await openSection(tester, 'Galería');
    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.textContaining('1 foto nueva'), findsOneWidget);
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Nuevo'), findsOneWidget);
  });

  testWidgets('opening another section clears the new marks', (tester) async {
    await pumpShell(tester);
    await openSection(tester, 'Galería');
    expect(find.text('Nuevo'), findsOneWidget);
    await openSection(tester, 'Transferencias');
    await openSection(tester, 'Galería');
    expect(find.text('Nuevo'), findsNothing);
    expect(find.textContaining('foto nueva'), findsNothing);
  });

  testWidgets('hiding the window with the gallery on screen clears them too', (tester) async {
    await pumpShell(tester);
    await openSection(tester, 'Galería');
    // Losing focus alone is not leaving.
    await lifecycle(tester, AppLifecycleState.inactive);
    expect(find.text('Nuevo'), findsOneWidget);
    await lifecycle(tester, AppLifecycleState.hidden);
    await lifecycle(tester, AppLifecycleState.resumed);
    expect(find.text('Nuevo'), findsNothing);
  });

  testWidgets('leaving another section does not touch them', (tester) async {
    await pumpShell(tester);
    await openSection(tester, 'Actividad');
    await lifecycle(tester, AppLifecycleState.hidden);
    await lifecycle(tester, AppLifecycleState.resumed);
    await openSection(tester, 'Galería');
    expect(find.text('Nuevo'), findsOneWidget);
  });
}
