import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/app/router.dart';
import 'package:pepoconnect/app/theme.dart';
import 'package:pepoconnect/dev/fakes.dart';
import 'package:pepoconnect/features/onboarding/onboarding_page.dart';
import 'package:pepoconnect/features/pairing/pairing_page.dart';
import 'package:pepoconnect/features/settings/settings_page.dart';
import 'package:pepoconnect/features/settings/settings_providers.dart';
import 'package:pepoconnect/shared/i18n/l10n.dart';
import 'package:pepoconnect/shared/motion/motion_scope.dart';
import 'package:pepoconnect/state/app_settings.dart';
import 'package:pepoconnect/state/engine_providers.dart';

/// Engine facts without an engine.
const LocalDeviceFacts testFacts = LocalDeviceFacts(
  deviceName: 'GEORGY',
  systemName: 'georgy-pc',
  shortId: 'PEPO-AB12-CD34',
  downloadRoot: r'C:\Users\dan\Pictures\PepoConnect',
  appVersion: '0.1.0',
);

/// Pairing without an engine. `123456` is the only accepted manual code.
class FakePairingNotifier extends PairingNotifier {
  FakePairingNotifier([this.initial, this.validity = const Duration(minutes: 2)]);

  final PairingInvite? initial;

  /// How long the invitations this fake hands out last.
  final Duration validity;
  int qrStarts = 0;
  int codeStarts = 0;
  int cancels = 0;
  final List<String> pairedTexts = [];

  @override
  PairingInvite? build() => initial;

  @override
  Future<PairingInvite> startQr() async {
    qrStarts++;
    final invite = fakeInvite(validity: validity);
    state = invite;
    return invite;
  }

  @override
  Future<PairingInvite> startCode() async {
    codeStarts++;
    final invite = fakeInvite(mode: PairingMode.manualCode, validity: validity);
    state = invite;
    return invite;
  }

  @override
  void cancel() {
    cancels++;
    state = null;
  }

  @override
  Future<PairedDevice> pairWithText(String text) async {
    pairedTexts.add(text);
    if (QrPayload.tryParse(text) == null && !text.startsWith('pepoconnect://')) {
      throw HandshakeException('not a PepoConnect code', code: ErrorCode.badRequest);
    }
    return fakePairedDevice(id: 'georgy', name: 'GEORGY', platform: DevicePlatform.windows);
  }

  @override
  Future<PairedDevice> pairWithCode({
    required String code,
    PeerCandidate? candidate,
    String? host,
    int? port,
  }) async {
    if (code != '123456') {
      throw HandshakeException('pairing rejected: bad pairing proof', code: ErrorCode.rejected);
    }
    return fakePairedDevice(
      id: 'laptop',
      name: candidate?.name ?? 'Portátil',
      platform: DevicePlatform.windows,
    );
  }

  @override
  List<PeerCandidate> discovered() => const [];

  @override
  Future<List<String>> localAddresses() async => const ['192.168.1.20'];
}

/// Devices that tests can grow at will.
class TestDevicesNotifier extends FakeDevicesNotifier {
  TestDevicesNotifier(super.initial);

  void add(DeviceView view) => state = [...state, view];
}

PairingInvite fakeInvite({
  PairingMode mode = PairingMode.qr,
  Duration validity = const Duration(minutes: 2),
}) => PairingInvite(
  mode: mode,
  expiresAt: DateTime.now().add(validity),
  qrText: mode == PairingMode.qr
      ? 'pepoconnect://pair/1?id=01234567890123456789012345&n=GEORGY&a=192.168.1.20&p=47473'
      : null,
  code: mode == PairingMode.manualCode ? '482913' : null,
  addresses: const ['192.168.1.20'],
  port: 47473,
);

PairedDevice fakePairedDevice({
  required String id,
  required String name,
  DevicePlatform platform = DevicePlatform.android,
  String? model,
  DateTime? pairedAt,
}) => PairedDevice(
  deviceId: id.padRight(16, '0'),
  name: name,
  platform: platform,
  role: platform.isMobile ? DeviceRole.phone : DeviceRole.both,
  fingerprint: 'ab' * 32,
  psk: Uint8List(32),
  weInitiate: false,
  pairedAt: pairedAt ?? DateTime.now(),
  model: model,
);

DeviceView viewOf(PairedDevice device, {bool connected = true}) => DeviceView(
  device: device,
  connected: connected,
  connecting: false,
  status: const DeviceStatus(),
  connectedAt: connected ? DateTime.now() : null,
);

/// Everything the three features read, without an engine.
List<Override> featureOverrides({
  AppSettings settings = const AppSettings(animations: false),
  List<DeviceView>? devices,
  TestDevicesNotifier? devicesNotifier,
  FakePairingNotifier? pairing,
}) => [
  settingsProvider.overrideWith(() => FakeSettingsNotifier(settings)),
  devicesProvider.overrideWith(
    () => devicesNotifier ?? TestDevicesNotifier(devices ?? sampleDevices()),
  ),
  transfersProvider.overrideWith(FakeTransfersNotifier.new),
  unreadActivityProvider.overrideWithValue(0),
  pairingProvider.overrideWith(() => pairing ?? FakePairingNotifier()),
  discoveredDevicesProvider.overrideWith((ref) => Stream.value(const <PeerCandidate>[])),
  localDeviceFactsProvider.overrideWithValue(testFacts),
];

/// The feature pages plus text stand-ins for the shell branches.
GoRouter testRouter({required String initialLocation, bool mobile = false}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, _) => OnboardingPage(mobile: mobile),
    ),
    GoRoute(
      path: AppRoutes.pair,
      builder: (_, _) => PairingPage(mobile: mobile),
    ),
    GoRoute(path: AppRoutes.settings, builder: (_, _) => const SettingsPage()),
    GoRoute(
      path: AppRoutes.transfers,
      builder: (_, state) => Text('transfers ${state.uri.query}'.trim()),
    ),
    GoRoute(path: AppRoutes.gallery, builder: (_, _) => const Text('gallery')),
  ],
);

Future<void> pumpApp(
  WidgetTester tester, {
  required List<Override> overrides,
  required GoRouter router,
  Size size = const Size(1200, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildLightTheme(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MotionScope(enabled: false, child: child!),
      ),
    ),
  );
  await tester.pump();
}

ProviderContainer containerOf(WidgetTester tester, Type pageType) =>
    ProviderScope.containerOf(tester.element(find.byType(pageType)));

/// Tears the tree down so periodic timers (the invite countdown) stop.
Future<void> tearDownApp(WidgetTester tester) => tester.pumpWidget(const SizedBox.shrink());
