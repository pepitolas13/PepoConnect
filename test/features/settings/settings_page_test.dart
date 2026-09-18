import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/app/router.dart';
import 'package:pepoconnect/features/settings/settings_page.dart';
import 'package:pepoconnect/features/settings/settings_widgets.dart';
import 'package:pepoconnect/shared/widgets/pepo_dialog.dart';
import 'package:pepoconnect/shared/widgets/toggle_switch.dart';
import 'package:pepoconnect/state/app_settings.dart';

import '../pairing/test_support.dart';

void main() {
  testWidgets('shows the three theme cards and changes the theme mode', (tester) async {
    await pumpApp(
      tester,
      overrides: featureOverrides(),
      router: testRouter(initialLocation: AppRoutes.settings),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ThemeCard), findsNWidgets(3));
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);
    expect(find.widgetWithText(ThemeCard, 'Según el sistema'), findsOneWidget);
    expect(
      tester.widget<ThemeCard>(find.widgetWithText(ThemeCard, 'Según el sistema')).selected,
      isTrue,
    );

    await tester.ensureVisible(find.text('Oscuro'));
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    final container = containerOf(tester, SettingsPage);
    expect(container.read(settingsProvider).themeMode, AppThemeMode.dark);
    expect(tester.widget<ThemeCard>(find.widgetWithText(ThemeCard, 'Oscuro')).selected, isTrue);
  });

  testWidgets('executables are off by default and the row says what that means', (tester) async {
    // Tall enough for the storage section, which sits at the bottom.
    await pumpApp(
      tester,
      overrides: featureOverrides(),
      router: testRouter(initialLocation: AppRoutes.settings),
      size: const Size(1200, 2400),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('no se envían ni se reciben programas'), findsOneWidget);
    final row = find.ancestor(
      of: find.text('Permitir ejecutables'),
      matching: find.byType(SettingsRow),
    );
    final toggle = find.descendant(of: row, matching: find.byType(ToggleSwitch));
    expect(tester.widget<ToggleSwitch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(containerOf(tester, SettingsPage).read(settingsProvider).allowExecutables, isTrue);
    expect(tester.widget<ToggleSwitch>(toggle).value, isTrue);
  });

  testWidgets('lists the paired devices with a remove button and forgets one', (tester) async {
    await pumpApp(
      tester,
      overrides: featureOverrides(),
      router: testRouter(initialLocation: AppRoutes.settings),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mis dispositivos'), findsOneWidget);
    expect(find.text('Pixel 8'), findsOneWidget);
    expect(find.text('Quitar'), findsNWidgets(3));

    await tester.tap(find.text('Quitar').first);
    await tester.pumpAndSettle();
    expect(find.byType(PepoDialog), findsOneWidget);
    expect(find.text('¿Quieres olvidar "Pixel 8"?'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(PepoDialog), matching: find.text('Quitar')));
    await tester.pumpAndSettle();
    expect(find.byType(PepoDialog), findsNothing);
    expect(find.text('Pixel 8'), findsNothing);
    expect(find.text('Quitar'), findsNWidgets(2));
  });

  testWidgets('the navigation list switches sections', (tester) async {
    await pumpApp(
      tester,
      overrides: featureOverrides(),
      router: testRouter(initialLocation: AppRoutes.settings),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mi PC'), findsOneWidget);
    expect(find.text('GEORGY'), findsOneWidget);
    expect(find.text('Sonidos'), findsNothing);

    await tester.tap(find.text('Notificaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Sonidos'), findsOneWidget);
    expect(find.text('Mi PC'), findsNothing);

    await tester.tap(find.text('Acerca de'));
    await tester.pumpAndSettle();
    expect(find.text('PEPO-AB12-CD34'), findsOneWidget);
    expect(find.text('Versión 0.1.0'), findsWidgets);
    expect(find.text('Comprobar actualizaciones'), findsWidgets);
  });

  testWidgets('narrow widths stack every section under a heading', (tester) async {
    await pumpApp(
      tester,
      overrides: featureOverrides(),
      router: testRouter(initialLocation: AppRoutes.settings),
      size: const Size(400, 900),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.byType(SettingsSectionTitle), findsWidgets);
    expect(find.text('Mi PC'), findsOneWidget);
  });
}
