import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/features/settings/sections/phone_section.dart';
import 'package:pepoconnect/features/settings/settings_widgets.dart';
import 'package:pepoconnect/platform/pepo_native.dart';
import 'package:pepoconnect/shared/widgets/toggle_switch.dart';
import 'package:pepoconnect/state/app_settings.dart';

import '../../ui/harness.dart';
import '../pairing/test_support.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.pepoconnect/native');
  final messenger = binding.defaultBinaryMessenger;
  Map<String, Object?> status = const {};

  final hub = viewOf(
    fakePairedDevice(id: 'torre', name: 'Torre', platform: DevicePlatform.windows),
  );

  setUp(() {
    status = const {'running': false, 'playing': false, 'held': false, 'refresh': 'available'};
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'backgroundStatus' ? status : null,
    );
  });

  tearDown(() {
    PepoNative.debugPlatform = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<ProviderContainer> pumpSection(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(animations: false),
    List<DeviceView>? devices,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: featureOverrides(settings: settings, devices: devices ?? [hub]),
        child: harness(
          animations: false,
          child: const SingleChildScrollView(child: PhoneSection()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(PhoneSection)));
  }

  /// Stops the 5 s status poll before the test ends.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('on iPhone the switch says what it really does and the state is shown', (
    tester,
  ) async {
    PepoNative.debugPlatform = 'ios';
    await pumpSection(tester);

    expect(
      find.textContaining('Mantiene PepoConnect en marcha con la app cerrada'),
      findsOneWidget,
    );
    expect(find.text('Estado del segundo plano'), findsOneWidget);
    expect(find.text('Parado'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a running engine shows how long the process has been alive', (tester) async {
    PepoNative.debugPlatform = 'ios';
    status = {
      'running': true,
      'playing': true,
      'held': false,
      'refresh': 'available',
      'startedAt': DateTime.now().subtract(const Duration(minutes: 47)).millisecondsSinceEpoch,
    };
    await pumpSection(tester);

    expect(find.text('Activo desde hace 47 min'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a session lost to another app reads as recovering', (tester) async {
    PepoNative.debugPlatform = 'ios';
    status = const {'running': true, 'playing': false, 'held': false, 'refresh': 'available'};
    await pumpSection(tester);

    expect(find.text('Recuperándose…'), findsOneWidget);
    await close(tester);
  });

  testWidgets('on Android the row is not there and the text is the service one', (tester) async {
    PepoNative.debugPlatform = 'android';
    await pumpSection(tester);

    expect(find.text('Mantiene la conexión con el PC'), findsOneWidget);
    expect(find.text('Estado del segundo plano'), findsNothing);
    await close(tester);
  });

  testWidgets('the auto-send switch only writes the setting', (tester) async {
    PepoNative.debugPlatform = 'android';
    final container = await pumpSection(tester);
    final row = find.ancestor(
      of: find.text('Enviar fotos nuevas automáticamente'),
      matching: find.byType(SettingsRow),
    );
    final toggle = find.descendant(of: row, matching: find.byType(ToggleSwitch));
    expect(tester.widget<ToggleSwitch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final settings = container.read(settingsProvider);
    expect(settings.autoSendPhotos, isTrue);
    expect(
      settings.defaultHubId,
      hub.deviceId,
      reason: 'the only paired PC becomes the hub, and AppServices applies it',
    );
    await close(tester);
  });

  testWidgets('with no PC paired the switch stays off', (tester) async {
    PepoNative.debugPlatform = 'android';
    final container = await pumpSection(tester, devices: const []);
    final row = find.ancestor(
      of: find.text('Enviar fotos nuevas automáticamente'),
      matching: find.byType(SettingsRow),
    );
    await tester.tap(find.descendant(of: row, matching: find.byType(ToggleSwitch)));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).autoSendPhotos, isFalse);
    await close(tester);
  });
}
