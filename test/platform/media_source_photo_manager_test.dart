import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/platform/media_source_photo_manager.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.fluttercandies/photo_manager');
  final messenger = binding.defaultBinaryMessenger;
  late Directory cache;
  late MediaSourcePhotoManager source;
  late List<Map<String, Object>> assets;
  late List<MediaItem> additions;
  late StreamSubscription<MediaChange> subscription;

  Map<String, Object> asset(String id, {int type = 1, DateTime? date}) => {
    'id': id,
    'type': type,
    'width': 1920,
    'height': 1080,
    'title': '$id.${type == 2 ? 'mp4' : 'jpg'}',
    'createDt': (date ?? DateTime(2020)).millisecondsSinceEpoch ~/ 1000,
  };

  Future<void> notify() async {
    await messenger.handlePlatformMessage(
      '${channel.name}/notify',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('change')),
      (_) {},
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('pepo-gallery-test');
    assets = [asset('existing')];
    additions = [];
    // Emulate the native date filter. Keep the real photo_manager path,
    // serialization, callbacks and PepoConnect scanning code in the test.
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'notify') return true;
      final args = call.arguments as Map;
      final option = args['option'] as Map?;
      final dates = (option?['child'] as Map?)?['createDate'] as Map?;
      final visible = assets.where((a) {
        if (dates == null || dates['ignore'] == true) return true;
        final time = (a['createDt'] as int) * 1000;
        return time >= (dates['min'] as int) && time <= (dates['max'] as int);
      }).toList();
      switch (call.method) {
        case 'getAssetPathList':
          return {
            'data': [
              {'id': 'all', 'name': 'All', 'isAll': true, 'assetCount': visible.length},
            ],
          };
        case 'getAssetCountFromPath':
          return visible.length;
        case 'getAssetListRange':
          return {
            'data': visible
                .skip(args['start'] as int)
                .take((args['end'] as int) - (args['start'] as int))
                .toList(),
          };
        case 'getAssetListPaged':
          return {
            'data': visible
                .skip((args['page'] as int) * (args['size'] as int))
                .take(args['size'] as int)
                .toList(),
          };
        default:
          throw StateError('Unexpected photo_manager call: ${call.method}');
      }
    });
    source = MediaSourcePhotoManager(
      cacheDir: cache.path,
      pollFallback: const Duration(milliseconds: 100),
      debounce: const Duration(milliseconds: 1),
      settleDelays: const [],
    );
    subscription = source.changes.listen((change) => additions.addAll(change.added));
    await source.start();
    expect(source.permissionMissing, isFalse);
  });

  tearDown(() async {
    await source.stop();
    await subscription.cancel();
    source.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    await cache.delete(recursive: true);
  });

  for (final lifecycle in [AppLifecycleState.resumed, AppLifecycleState.paused]) {
    test('pushes new photos and videos while $lifecycle without restarting', () async {
      binding.handleAppLifecycleStateChanged(lifecycle);
      final later = DateTime.now().add(const Duration(hours: 1));
      assets.insertAll(0, [asset('photo', date: later), asset('video', type: 2, date: later)]);
      await notify();
      expect(additions.map((a) => a.id), ['photo', 'video']);
      expect(additions.map((a) => a.kind), [MediaKind.image, MediaKind.video]);
      final page = await source.index();
      expect(page.items.map((a) => a.id), ['photo', 'video', 'existing']);
      expect(page.total, 3);
      await notify();
      expect(additions.length, 2, reason: 'Repeated notifications must not duplicate media');
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }

  test('fallback catches a missed notification even after a recent observer event', () async {
    await notify();
    assets.insert(0, asset('missed'));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(additions.map((a) => a.id), ['missed']);
  });
}
