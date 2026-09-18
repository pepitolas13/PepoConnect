import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/app/router.dart';
import 'package:pepoconnect/features/onboarding/desktop_onboarding.dart';
import 'package:pepoconnect/features/onboarding/mobile_onboarding.dart';
import 'package:pepoconnect/features/onboarding/onboarding_page.dart';
import 'package:pepoconnect/features/pairing/pairing_page.dart';
import 'package:pepoconnect/state/app_settings.dart';

import '../pairing/test_support.dart';

void main() {
  testWidgets('desktop onboarding offers the two ways to use the app', (tester) async {
    await pumpApp(
      tester,
      overrides: featureOverrides(devices: const []),
      router: testRouter(initialLocation: AppRoutes.onboarding),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingChoiceCard), findsNWidgets(2));
    expect(find.text('¿Cómo quieres usar PepoConnect?'), findsOneWidget);
    expect(find.text('Conecta tu móvil'), findsOneWidget);
    expect(find.text('Comparte con cualquiera'), findsOneWidget);
    expect(find.text('Añadir móvil'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);
    expect(find.text('Saltar por ahora'), findsOneWidget);
  });

  testWidgets('skipping marks the onboarding done and opens transfers', (tester) async {
    await pumpApp(
      tester,
      overrides: featureOverrides(devices: const []),
      router: testRouter(initialLocation: AppRoutes.onboarding),
    );
    await tester.pumpAndSettle();
    final container = containerOf(tester, OnboardingPage);
    expect(container.read(settingsProvider).onboarded, isFalse);

    await tester.tap(find.text('Saltar por ahora'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).onboarded, isTrue);
    expect(find.text('transfers'), findsOneWidget);
  });

  testWidgets('sharing opens transfers in guest mode', (tester) async {
    await pumpApp(
      tester,
      overrides: featureOverrides(devices: const []),
      router: testRouter(initialLocation: AppRoutes.onboarding),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Compartir'));
    await tester.pumpAndSettle();
    expect(find.text('transfers guest=1'), findsOneWidget);
  });

  testWidgets('adding a phone opens the pairing page', (tester) async {
    await pumpApp(
      tester,
      overrides: featureOverrides(devices: const []),
      router: testRouter(initialLocation: AppRoutes.onboarding),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Añadir móvil'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PairingPage), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('mobile onboarding walks the slides and ends on permissions', (tester) async {
    await pumpApp(
      tester,
      overrides: featureOverrides(devices: const []),
      router: testRouter(initialLocation: AppRoutes.onboarding, mobile: true),
      size: const Size(400, 860),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MobileOnboarding), findsOneWidget);
    expect(find.byType(PageDots), findsOneWidget);
    expect(find.text('Pasa fotos y archivos entre este móvil y tu PC'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Cada foto nueva aparece en el PC al momento'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Todo por tu red, cifrado, sin cuentas'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Permisos necesarios'), findsOneWidget);
    expect(find.text('Fotos y vídeos'), findsOneWidget);
    expect(find.text('Sin restricción de batería'), findsOneWidget);
    // Not a phone: everything counts as granted.
    expect(find.text('Concedido'), findsNWidgets(3));
    expect(find.text('Continuar'), findsOneWidget);
  });
}
