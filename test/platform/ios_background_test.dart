import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/platform/ios_background.dart';
import 'package:pepoconnect/platform/pepo_native.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.pepoconnect/native');
  final messenger = binding.defaultBinaryMessenger;
  late List<MethodCall> calls;
  Map<String, Object?> status = const {};

  setUp(() {
    calls = [];
    status = const {'running': true, 'playing': true, 'held': false, 'refresh': 'available'};
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'keepAliveStart' => true,
        'backgroundHold' => (call.arguments as Map)['on'] as bool,
        'backgroundStatus' => status,
        _ => null,
      };
    });
  });

  tearDown(() {
    PepoNative.debugPlatform = null;
    PepoNative.onBackgroundTask = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('off iOS', () {
    test('Android never hears about the keep-alive engine', () async {
      PepoNative.debugPlatform = 'android';
      expect(IosBackground.isSupported, isFalse);
      expect(await IosBackground.start(), isFalse);
      await IosBackground.stop();
      await IosBackground.hold(true);
      expect((await IosBackground.status()).running, isFalse);
      expect(calls, isEmpty, reason: 'the Android service is what holds it up there');
    });

    test('the desktop is untouched as well', () async {
      PepoNative.debugPlatform = 'windows';
      expect(IosBackground.isSupported, isFalse);
      await IosBackground.start();
      expect(calls, isEmpty);
    });
  });

  group('on iOS', () {
    setUp(() => PepoNative.debugPlatform = 'ios');

    test('start and stop drive the silent loop', () async {
      expect(await IosBackground.start(), isTrue);
      await IosBackground.stop();
      expect(calls.map((c) => c.method), ['keepAliveStart', 'keepAliveStop']);
    });

    test('a transfer in flight holds the process up and then lets go', () async {
      await IosBackground.hold(true);
      await IosBackground.hold(false);
      expect(calls.map((c) => c.method), ['backgroundHold', 'backgroundHold']);
      expect(calls.first.arguments, {'on': true});
      expect(calls.last.arguments, {'on': false});
    });

    test('the state comes back with the uptime the phone can show', () async {
      final started = DateTime(2026, 9, 18, 21, 30);
      status = {
        'running': true,
        'playing': true,
        'held': true,
        'refresh': 'available',
        'startedAt': started.millisecondsSinceEpoch,
      };
      final state = await IosBackground.status();
      expect(state.healthy, isTrue);
      expect(state.held, isTrue);
      expect(state.refresh, 'available');
      expect(state.startedAt, started);
    });

    test('running without playing is not healthy', () async {
      status = const {'running': true, 'playing': false, 'held': false, 'refresh': 'denied'};
      final state = await IosBackground.status();
      expect(state.running, isTrue);
      expect(state.healthy, isFalse, reason: 'the session was taken away');
    });

    test('a native side that answers nothing degrades to off', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      final state = await IosBackground.status();
      expect(state.running, isFalse);
      expect(state.startedAt, isNull);
    });

    test('a background task reaches Dart and is answered', () async {
      final seen = <String>[];
      PepoNative.onBackgroundTask = (id) async => seen.add(id);
      PepoNative.init();
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('backgroundTask', {'id': 'org.pepoconnect.app.sync'}),
        ),
        (_) {},
      );
      expect(seen, ['org.pepoconnect.app.sync']);

      await PepoNative.backgroundTaskDone('org.pepoconnect.app.sync');
      expect(calls.last.method, 'backgroundTaskDone');
      expect(calls.last.arguments, {'id': 'org.pepoconnect.app.sync', 'ok': true});
    });

    test('a task arriving with nobody listening is not an error', () async {
      PepoNative.onBackgroundTask = null;
      PepoNative.init();
      await expectLater(
        messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('backgroundTask', {'id': 'x'}),
          ),
          (_) {},
        ),
        completes,
      );
    });
  });
}
