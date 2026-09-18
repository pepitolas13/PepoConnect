import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/app/router.dart';
import 'package:pepoconnect/features/onboarding/onboarding_page.dart';
import 'package:pepoconnect/state/app_settings.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'test_support.dart';

void main() {
  testWidgets('shows a QR while an invitation is active', (tester) async {
    final pairing = FakePairingNotifier(fakeInvite());
    await pumpApp(
      tester,
      overrides: featureOverrides(devices: const [], pairing: pairing),
      router: testRouter(initialLocation: AppRoutes.pair),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Empareja tu móvil y tu PC'), findsOneWidget);
    expect(find.text('Instala PepoConnect en el móvil'), findsOneWidget);
    expect(find.text('Abre la app y escanea este código'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('Caduca en'), findsOneWidget);
    expect(find.text('Generar otro código'), findsOneWidget);
    // Opening the page asks for a fresh invitation.
    expect(pairing.qrStarts, 1);

    // Going back drops the invitation and, on a first run, returns to the
    // onboarding.
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    expect(pairing.cancels, 1);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('asks for a new QR when the countdown runs out', (tester) async {
    final pairing = FakePairingNotifier(null, const Duration(seconds: 3));
    await pumpApp(
      tester,
      overrides: featureOverrides(devices: const [], pairing: pairing),
      router: testRouter(initialLocation: AppRoutes.pair),
    );
    await tester.pump();
    await tester.pump();
    expect(pairing.qrStarts, 1);
    expect(find.text('Caduca en 0:03'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Caduca en 0:01'), findsOneWidget);
    expect(pairing.qrStarts, 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(pairing.qrStarts, 2);
    expect(find.byType(QrImageView), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('a dropped invitation shows as expired until regenerated', (tester) async {
    final pairing = FakePairingNotifier();
    await pumpApp(
      tester,
      overrides: featureOverrides(devices: const [], pairing: pairing),
      router: testRouter(initialLocation: AppRoutes.pair),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);

    // The engine drops an invitation after too many bad attempts.
    pairing.cancel();
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('El código ha caducado'), findsOneWidget);

    await tester.tap(find.text('Generar otro código'));
    await tester.pump();
    await tester.pump();
    expect(pairing.qrStarts, 2);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('El código ha caducado'), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('shows "Emparejado" when a new device appears', (tester) async {
    final devices = TestDevicesNotifier([]);
    await pumpApp(
      tester,
      overrides: featureOverrides(devicesNotifier: devices, pairing: FakePairingNotifier()),
      router: testRouter(initialLocation: AppRoutes.pair),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Emparejado'), findsNothing);

    devices.add(viewOf(fakePairedDevice(id: 'pixel9', name: 'Pixel 9', model: 'Pixel 9')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Emparejado'), findsOneWidget);
    expect(find.text('Tu PC y tu móvil ya están conectados'), findsOneWidget);
    expect(find.text('Pixel 9'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    final container = containerOf(tester, Text);
    expect(container.read(settingsProvider).onboarded, isTrue);
    expect(find.text('gallery'), findsOneWidget);
  });

  testWidgets('devices that were already paired do not count as new', (tester) async {
    final old = viewOf(
      fakePairedDevice(id: 'old', name: 'Viejo', pairedAt: DateTime(2026, 3, 1)),
      connected: false,
    );
    final devices = TestDevicesNotifier([]);
    await pumpApp(
      tester,
      overrides: featureOverrides(devicesNotifier: devices, pairing: FakePairingNotifier()),
      router: testRouter(initialLocation: AppRoutes.pair),
    );
    await tester.pump();
    // The list finishing its first load must not look like a pairing.
    devices.add(old);
    await tester.pump();
    await tester.pump();
    expect(find.text('Emparejado'), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('the code mode shows the six digits and this PC address', (tester) async {
    final pairing = FakePairingNotifier();
    await pumpApp(
      tester,
      overrides: featureOverrides(devices: const [], pairing: pairing),
      router: testRouter(initialLocation: AppRoutes.pair),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Usar código en lugar de QR'));
    await tester.pump();
    await tester.pump();

    expect(pairing.codeStarts, 1);
    expect(find.text('482 913'), findsOneWidget);
    expect(find.text('Tu PC: 192.168.1.20:47473'), findsOneWidget);
    expect(find.text('Escríbelo en el otro PC en Emparejar › Introducir código'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('pairing with another PC reports a wrong code and then succeeds', (tester) async {
    final pairing = FakePairingNotifier();
    await pumpApp(
      tester,
      overrides: featureOverrides(devices: const [], pairing: pairing),
      router: testRouter(initialLocation: AppRoutes.pair),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Conectar con otro PC'));
    await tester.pump();
    await tester.pump();
    // Switching away from the QR drops the invitation.
    expect(pairing.state, isNull);
    expect(find.text('Buscando PCs en la red…'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '192.168.1.30:47473');
    await tester.enterText(find.byType(TextField).at(1), '111111');
    await tester.pump();
    await tester.tap(find.text('Emparejar'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Código incorrecto. Comprueba los seis dígitos'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.pump();
    await tester.tap(find.text('Emparejar'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Emparejado'), findsOneWidget);
    expect(find.text('Portátil'), findsOneWidget);
  });

  test('fake invitation is a valid pairing payload shape', () {
    final invite = fakeInvite();
    expect(invite.mode, PairingMode.qr);
    expect(invite.qrText, startsWith('pepoconnect://pair/'));
  });
}
