import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/state/stores.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pepo_states_');
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  File fileFor(String deviceId) => File(p.join(dir.path, 'gallery', '$deviceId.json'));

  test('keeps item states and the seen-until watermark across instances', () async {
    final store = JsonMediaStateStore(dir.path);
    final until = DateTime.utc(2026, 9, 18, 12, 30);
    await store.save('dev1', MediaItemState(id: 'a', state: MediaState.fresh));
    await store.saveSeenUntil('dev1', until);
    expect(await store.loadSeenUntil('dev1'), until);
    // Writes are debounced.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(fileFor('dev1').existsSync(), isTrue);

    final again = JsonMediaStateStore(dir.path);
    expect((await again.load('dev1'))['a']!.state, MediaState.fresh);
    expect(await again.loadSeenUntil('dev1'), until);
    expect(await again.loadSeenUntil('dev2'), isNull);
  });

  test('still reads the bare-list format written before the watermark', () async {
    final f = fileFor('dev1');
    await f.parent.create(recursive: true);
    await f.writeAsString(
      jsonEncode([
        MediaItemState(id: 'a', state: MediaState.downloaded, localPath: r'C:\x\a.jpg').toJson(),
      ]),
    );
    final store = JsonMediaStateStore(dir.path);
    final states = await store.load('dev1');
    expect(states['a']!.state, MediaState.downloaded);
    expect(states['a']!.localPath, r'C:\x\a.jpg');
    expect(await store.loadSeenUntil('dev1'), isNull);
  });

  test('removeDevice drops the file and the watermark', () async {
    final store = JsonMediaStateStore(dir.path);
    await store.saveSeenUntil('dev1', DateTime.utc(2026));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await store.removeDevice('dev1');
    expect(fileFor('dev1').existsSync(), isFalse);
    expect(await store.loadSeenUntil('dev1'), isNull);
  });
}
