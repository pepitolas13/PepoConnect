import 'dart:async';

import 'package:pepo_core/src/media/auto_send_queue.dart';
import 'package:test/test.dart';

const hub = 'HUB00000000000000000000000';
const other = 'OTH00000000000000000000000';

/// Records what the queue tried to send and answers with whatever the test
/// lined up for that item.
class FakeSender {
  final List<String> calls = [];
  final Map<String, AutoSendResult> answers = {};
  AutoSendResult fallback = AutoSendResult.sent;
  Set<String> reachable = {hub, other};

  /// Holds the next send open, so a test can make something else happen
  /// while it is in flight.
  Completer<AutoSendResult>? gate;

  Future<AutoSendResult> send(String deviceId, String itemId) async {
    calls.add('$deviceId/$itemId');
    final held = gate;
    if (held != null) {
      gate = null;
      return held.future;
    }
    return answers['$deviceId/$itemId'] ?? fallback;
  }

  bool isReachable(String deviceId) => reachable.contains(deviceId);
}

AutoSendQueue queueOn(
  FakeSender sender,
  AutoSendStore store, {
  int maxPending = 200,
  int maxDone = 500,
  int maxAttempts = 8,
  Duration maxAge = const Duration(days: 7),
}) => AutoSendQueue(
  store: store,
  send: sender.send,
  isReachable: sender.isReachable,
  maxPending: maxPending,
  maxDone: maxDone,
  maxAttempts: maxAttempts,
  maxAge: maxAge,
);

void main() {
  late FakeSender sender;
  late MemoryAutoSendStore store;
  late AutoSendQueue queue;

  setUp(() {
    sender = FakeSender();
    store = MemoryAutoSendStore();
    queue = queueOn(sender, store);
  });

  test('a new photo goes out as soon as it is queued', () async {
    await queue.setTargets([hub]);
    await queue.add('photo-1');
    expect(sender.calls, ['$hub/photo-1']);
    expect(queue.isEmpty, isTrue);
  });

  test('nothing is queued while the switch is off', () async {
    await queue.add('photo-1');
    expect(sender.calls, isEmpty);
    expect(queue.isEmpty, isTrue);
  });

  test('a photo taken with the PC off waits and goes out on reconnect', () async {
    await queue.setTargets([hub]);
    sender.reachable = {};
    await queue.add('photo-1');
    expect(sender.calls, isEmpty);
    expect(queue.pendingCount, 1);

    sender.reachable = {hub};
    await queue.drain();
    expect(sender.calls, ['$hub/photo-1']);
    expect(queue.isEmpty, isTrue);
  });

  test('the queue survives a restart and does not send twice', () async {
    await queue.setTargets([hub]);
    sender.reachable = {};
    await queue.add('photo-1');

    // Same store, new process.
    final restarted = queueOn(sender, store);
    await restarted.load();
    await restarted.setTargets([hub]);
    sender.reachable = {hub};
    await restarted.drain();
    expect(sender.calls, ['$hub/photo-1']);

    await restarted.add('photo-1');
    expect(sender.calls, ['$hub/photo-1'], reason: 'already sent once');
  });

  test('re-applying the setting at start keeps the original enabledSince', () async {
    final before = DateTime.utc(2026, 9, 1);
    await queue.setTargets([hub], now: before);
    expect(queue.enabledSince, before);

    final restarted = queueOn(sender, store);
    await restarted.setTargets([hub], now: DateTime.utc(2026, 9, 18));
    expect(
      restarted.enabledSince,
      before,
      reason: 'moving it forward would hide every photo taken while dead',
    );
  });

  test('photos older than the switch being turned on are left alone', () async {
    await queue.setTargets([hub], now: DateTime.utc(2026, 9, 10));
    await queue.add('old', takenAt: DateTime.utc(2026, 9, 9));
    await queue.add('new', takenAt: DateTime.utc(2026, 9, 11));
    expect(sender.calls, ['$hub/new']);
  });

  test('turning the switch off drops what was still queued', () async {
    await queue.setTargets([hub]);
    sender.reachable = {};
    await queue.add('photo-1');
    expect(queue.pendingCount, 1);

    await queue.setTargets(const []);
    expect(queue.pendingCount, 0);
    expect(queue.enabledSince, isNull);
  });

  test('changing the hub drops the old one and keeps the new', () async {
    await queue.setTargets([hub]);
    sender.reachable = {};
    await queue.add('photo-1');
    await queue.setTargets([other]);
    expect(queue.pendingCount, 0);

    sender.reachable = {other};
    await queue.add('photo-2');
    expect(sender.calls, ['$other/photo-2']);
  });

  test('every target gets its own copy', () async {
    await queue.setTargets([hub, other]);
    await queue.add('photo-1');
    expect(sender.calls, containsAll(['$hub/photo-1', '$other/photo-1']));
    expect(sender.calls.length, 2);
  });

  test('a deleted photo is dropped instead of retried forever', () async {
    await queue.setTargets([hub]);
    sender.answers['$hub/gone'] = AutoSendResult.skip;
    await queue.add('gone');
    expect(queue.isEmpty, isTrue);

    await queue.drain();
    expect(sender.calls, ['$hub/gone'], reason: 'not tried again');
  });

  test('a photo that keeps failing is given up on after maxAttempts', () async {
    queue = queueOn(sender, store, maxAttempts: 3);
    await queue.setTargets([hub]);
    sender.fallback = AutoSendResult.retry;
    await queue.add('stuck');
    expect(queue.pendingCount, 1);
    await queue.drain();
    expect(queue.pendingCount, 1);
    await queue.drain();
    expect(queue.pendingCount, 0, reason: 'three tries is enough');
    expect(sender.calls.length, 3);
  });

  test('one device refusing does not burn the other device queue', () async {
    await queue.setTargets([hub, other]);
    sender.reachable = {};
    await queue.add('photo-1');
    sender.reachable = {hub, other};
    sender.answers['$hub/photo-1'] = AutoSendResult.retry;
    await queue.drain();
    expect(sender.calls, containsAll(['$hub/photo-1', '$other/photo-1']));
    expect(queue.pendingCount, 1, reason: 'only the hub entry is left');
  });

  test('a backlog is capped at maxPending, newest kept', () async {
    queue = queueOn(sender, store, maxPending: 3);
    await queue.setTargets([hub]);
    sender.reachable = {};
    for (var i = 0; i < 6; i++) {
      await queue.add('photo-$i');
    }
    expect(queue.pendingCount, 3);

    sender.reachable = {hub};
    await queue.drain();
    expect(sender.calls, ['$hub/photo-3', '$hub/photo-4', '$hub/photo-5']);
  });

  test('entries older than maxAge are forgotten on the next drain', () async {
    // A queue file written days ago and loaded now.
    final stale = DateTime.now().subtract(const Duration(days: 2));
    await store.save(
      AutoSendData(
        enabledSince: stale.subtract(const Duration(days: 1)),
        pending: [AutoSendEntry(deviceId: hub, itemId: 'stale', queuedAt: stale)],
      ),
    );
    queue = queueOn(sender, store, maxAge: const Duration(hours: 1));
    await queue.load();
    expect(queue.pendingCount, 1);

    await queue.setTargets([hub]);
    await queue.drain();
    expect(sender.calls, isEmpty);
    expect(queue.pendingCount, 0);
  });

  test('the sent list is capped so it cannot grow without end', () async {
    queue = queueOn(sender, store, maxDone: 2);
    await queue.setTargets([hub]);
    for (var i = 0; i < 5; i++) {
      await queue.add('photo-$i');
    }
    final saved = await store.load();
    expect(saved.done, ['$hub/photo-3', '$hub/photo-4']);
  });

  test('the catch-up mark moves forward only', () async {
    final start = DateTime.utc(2026, 9, 10);
    await queue.setTargets([hub], now: start);
    expect(queue.catchUpFrom, start);

    await queue.markCaughtUp(DateTime.utc(2026, 9, 12));
    expect(queue.catchUpFrom, DateTime.utc(2026, 9, 12));

    await queue.markCaughtUp(DateTime.utc(2026, 9, 11));
    expect(queue.catchUpFrom, DateTime.utc(2026, 9, 12));
  });

  test('state round-trips through JSON', () async {
    await queue.setTargets([hub], now: DateTime.utc(2026, 9, 10));
    sender.reachable = {};
    await queue.add('photo-1');
    final json = (await store.load()).toJson();
    final back = AutoSendData.fromJson(json);
    expect(back.enabledSince, DateTime.utc(2026, 9, 10));
    expect(back.pending.single.deviceId, hub);
    expect(back.pending.single.itemId, 'photo-1');
  });

  test('a photo taken mid-drain is not lost', () async {
    await queue.setTargets([hub]);
    sender.reachable = {};
    await queue.add('photo-1');

    sender.reachable = {hub};
    final held = Completer<AutoSendResult>();
    sender.gate = held;
    final draining = queue.drain();
    await Future<void>.delayed(Duration.zero);

    // The camera fires while the first one is still on the wire.
    await queue.add('photo-2');
    held.complete(AutoSendResult.sent);
    await draining;

    expect(sender.calls, ['$hub/photo-1', '$hub/photo-2']);
    expect(queue.isEmpty, isTrue);
  });

  test('a broken store does not take the queue down with it', () async {
    queue = AutoSendQueue(
      store: _BrokenStore(),
      send: sender.send,
      isReachable: sender.isReachable,
    );
    await queue.setTargets([hub]);
    await queue.add('photo-1');
    expect(sender.calls, ['$hub/photo-1']);
  });
}

class _BrokenStore implements AutoSendStore {
  @override
  Future<AutoSendData> load() async => throw const FileSystemExceptionStub();

  @override
  Future<void> save(AutoSendData data) async => throw const FileSystemExceptionStub();
}

class FileSystemExceptionStub implements Exception {
  const FileSystemExceptionStub();
}
