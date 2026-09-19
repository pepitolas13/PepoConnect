import 'dart:async';

import 'package:logging/logging.dart';

final _log = Logger('pepo.media.autosend');

/// What one attempt at sending an item ended up as.
enum AutoSendResult {
  /// Handed over to the transfer engine, which owns it from here.
  sent,

  /// The item is not there any more (deleted, no readable original): drop it.
  skip,

  /// Could not be sent right now. It stays queued.
  retry,
}

/// One item waiting to go to one device.
class AutoSendEntry {
  const AutoSendEntry({
    required this.deviceId,
    required this.itemId,
    required this.queuedAt,
    this.attempts = 0,
  });

  final String deviceId;
  final String itemId;
  final DateTime queuedAt;

  /// Failed tries so far. A photo that never makes it must not wedge the
  /// queue behind it forever.
  final int attempts;

  String get key => '$deviceId/$itemId';

  AutoSendEntry retried() =>
      AutoSendEntry(deviceId: deviceId, itemId: itemId, queuedAt: queuedAt, attempts: attempts + 1);

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'itemId': itemId,
    'at': queuedAt.toUtc().toIso8601String(),
    'tries': attempts,
  };

  factory AutoSendEntry.fromJson(Map<String, dynamic> json) => AutoSendEntry(
    deviceId: json['deviceId'] as String,
    itemId: json['itemId'] as String,
    queuedAt: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    attempts: json['tries'] as int? ?? 0,
  );
}

/// Everything the queue keeps across restarts.
class AutoSendData {
  const AutoSendData({
    this.enabledSince,
    this.catchUpAt,
    this.pending = const [],
    this.done = const [],
  });

  /// When automatic sending was switched on. Nothing older is ever queued,
  /// so turning the switch on does not push the whole camera roll to the PC.
  final DateTime? enabledSince;

  /// Newest item the catch-up pass has already looked at. This is what makes
  /// a photo taken while the process was dead arrive at the next start
  /// instead of being silently skipped.
  final DateTime? catchUpAt;

  final List<AutoSendEntry> pending;

  /// `<deviceId>/<itemId>` already handed to the transfer engine.
  final List<String> done;

  AutoSendData copyWith({
    DateTime? enabledSince,
    DateTime? catchUpAt,
    List<AutoSendEntry>? pending,
    List<String>? done,
    bool clearEnabledSince = false,
  }) => AutoSendData(
    enabledSince: clearEnabledSince ? null : (enabledSince ?? this.enabledSince),
    catchUpAt: catchUpAt ?? this.catchUpAt,
    pending: pending ?? this.pending,
    done: done ?? this.done,
  );

  Map<String, dynamic> toJson() => {
    'enabledSince': ?enabledSince?.toUtc().toIso8601String(),
    'catchUpAt': ?catchUpAt?.toUtc().toIso8601String(),
    'pending': pending.map((e) => e.toJson()).toList(),
    'done': done,
  };

  factory AutoSendData.fromJson(Map<String, dynamic> json) {
    final pending = <AutoSendEntry>[];
    for (final e in (json['pending'] as List<dynamic>? ?? const [])) {
      try {
        pending.add(AutoSendEntry.fromJson((e as Map).cast<String, dynamic>()));
      } catch (_) {}
    }
    return AutoSendData(
      enabledSince: DateTime.tryParse(json['enabledSince'] as String? ?? ''),
      catchUpAt: DateTime.tryParse(json['catchUpAt'] as String? ?? ''),
      pending: pending,
      done: (json['done'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  static const empty = AutoSendData();
}

/// Where [AutoSendQueue] keeps its state.
abstract class AutoSendStore {
  Future<AutoSendData> load();
  Future<void> save(AutoSendData data);
}

/// In-memory store (tests, and any engine without a data directory).
class MemoryAutoSendStore implements AutoSendStore {
  AutoSendData _data = AutoSendData.empty;

  @override
  Future<AutoSendData> load() async => _data;

  @override
  Future<void> save(AutoSendData data) async => _data = data;
}

/// Makes "send every new photo to the PC" a promise instead of a coin flip.
///
/// Sending straight from the photo-library notification only works when the
/// peer happens to be connected at that instant. With the PC asleep, the
/// Wi-Fi switching over, or the phone's process freshly restarted, the photo
/// was simply dropped and never retried. This queue writes every pending item
/// to disk, hands it over as soon as the device is reachable again, and
/// remembers what already went so a restart does not send it twice.
class AutoSendQueue {
  AutoSendQueue({
    required this.store,
    required this.send,
    required this.isReachable,
    this.maxPending = 200,
    this.maxDone = 500,
    this.maxAttempts = 8,
    this.maxAge = const Duration(days: 7),
  });

  final AutoSendStore store;

  /// Tries to send one item. See [AutoSendResult].
  final Future<AutoSendResult> Function(String deviceId, String itemId) send;

  /// Whether that device has a live session at this moment.
  final bool Function(String deviceId) isReachable;

  /// A phone left offline for a week should not wake up and flood the PC.
  final int maxPending;
  final int maxDone;
  final int maxAttempts;
  final Duration maxAge;

  AutoSendData _data = AutoSendData.empty;
  final Set<String> _targets = {};

  /// Every change to [_data] queues up behind this. A photo landing while a
  /// reconnect is draining would otherwise have both sides write their own
  /// version of the state, and one of them would be lost.
  Future<void> _writes = Future<void>.value();
  bool _loaded = false;
  bool _draining = false;
  bool _again = false;

  /// Devices that get every new photo automatically.
  Set<String> get targets => Set.unmodifiable(_targets);

  bool get isEmpty => _data.pending.isEmpty;
  int get pendingCount => _data.pending.length;

  /// Nothing taken before this is ever queued.
  DateTime? get enabledSince => _data.enabledSince;

  /// Where the catch-up pass should start looking.
  DateTime? get catchUpFrom {
    final since = _data.enabledSince;
    final mark = _data.catchUpAt;
    if (since == null) return mark;
    if (mark == null) return since;
    return mark.toUtc().isAfter(since.toUtc()) ? mark : since;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      _data = await store.load();
    } catch (e) {
      _log.warning('cannot read the auto-send queue: $e');
      _data = AutoSendData.empty;
    }
  }

  /// Replaces the set of devices that get new photos. Switching it on for
  /// the first time stamps [enabledSince]; switching it off entirely drops
  /// whatever was still queued, because nobody asked for it any more.
  Future<void> setTargets(Iterable<String> deviceIds, {DateTime? now}) async {
    await load();
    final next = deviceIds.toSet();
    if (_setEquals(next, _targets)) return;
    _targets
      ..clear()
      ..addAll(next);
    await _mutate((data) {
      if (_targets.isEmpty) {
        return data.copyWith(pending: const [], clearEnabledSince: true);
      }
      var out = data;
      // Only the first time it is switched on. Re-applying the setting at
      // every start must not move the mark forward, or the photos taken
      // while the process was dead would all fall before it.
      if (out.enabledSince == null) {
        final at = now ?? DateTime.now();
        out = out.copyWith(enabledSince: at, catchUpAt: at);
      }
      // Anything queued for a device that is no longer a target is dead mail.
      return out.copyWith(
        pending: out.pending.where((e) => _targets.contains(e.deviceId)).toList(),
      );
    }, now: now);
  }

  /// Queues [itemId] for every target. [takenAt] is when the photo was taken;
  /// anything older than [enabledSince] is ignored.
  Future<void> add(String itemId, {DateTime? takenAt, DateTime? now}) async {
    await load();
    if (_targets.isEmpty) return;
    final since = _data.enabledSince;
    if (takenAt != null && since != null && takenAt.toUtc().isBefore(since.toUtc())) return;
    final at = now ?? DateTime.now();
    var added = false;
    await _mutate((data) {
      final pending = List<AutoSendEntry>.of(data.pending);
      final queued = pending.map((e) => e.key).toSet();
      final done = data.done.toSet();
      for (final deviceId in _targets) {
        final key = '$deviceId/$itemId';
        if (queued.contains(key) || done.contains(key)) continue;
        pending.add(AutoSendEntry(deviceId: deviceId, itemId: itemId, queuedAt: at));
        added = true;
      }
      return added ? data.copyWith(pending: pending) : data;
    }, now: at);
    if (added) await drain();
  }

  /// Sends everything that can be sent right now. A device that refuses is
  /// parked until the next call, so a PC that just went away does not burn
  /// the rest of its queue.
  Future<void> drain() async {
    await load();
    // A photo from last week is not something anyone is still waiting for,
    // and nothing else would ever clear it out of a queue that never drains.
    if (_prune(_data, DateTime.now()).pending.length != _data.pending.length) {
      await _mutate((data) => data);
    }
    if (_draining) {
      // A change landed mid-drain: go round again instead of dropping it.
      _again = true;
      return;
    }
    _draining = true;
    try {
      do {
        _again = false;
        await _drainOnce();
      } while (_again);
    } finally {
      _draining = false;
    }
  }

  Future<void> _drainOnce() async {
    if (_data.pending.isEmpty) return;
    final parked = <String>{};
    final sent = <String>{};
    final dropped = <String>{};
    final retried = <String>{};
    for (final entry in List<AutoSendEntry>.of(_data.pending)) {
      if (parked.contains(entry.deviceId)) continue;
      if (!_targets.contains(entry.deviceId) || !isReachable(entry.deviceId)) continue;
      AutoSendResult result;
      try {
        result = await send(entry.deviceId, entry.itemId);
      } catch (e) {
        _log.fine('auto-send of ${entry.itemId} failed: $e');
        result = AutoSendResult.retry;
      }
      switch (result) {
        case AutoSendResult.sent:
          sent.add(entry.key);
        case AutoSendResult.skip:
          dropped.add(entry.key);
        case AutoSendResult.retry:
          if (entry.attempts + 1 >= maxAttempts) {
            _log.info('giving up on ${entry.itemId} after ${entry.attempts + 1} tries');
            dropped.add(entry.key);
          } else {
            retried.add(entry.key);
          }
          parked.add(entry.deviceId);
      }
    }
    if (sent.isEmpty && dropped.isEmpty && retried.isEmpty) return;
    final gone = {...sent, ...dropped};
    // Expressed against whatever the state is when this lands, not against
    // the snapshot the loop above started from: a photo taken while these
    // were on the wire has to survive.
    await _mutate(
      (data) => data.copyWith(
        pending: [
          for (final e in data.pending)
            if (!gone.contains(e.key)) (retried.contains(e.key) ? e.retried() : e),
        ],
        done: [...data.done, ...sent],
      ),
    );
  }

  /// Remembers how far the catch-up pass got, so the next start only looks
  /// at what came after.
  Future<void> markCaughtUp(DateTime at) async {
    await load();
    final current = _data.catchUpAt;
    if (current != null && !at.toUtc().isAfter(current.toUtc())) return;
    await _mutate((data) => data.copyWith(catchUpAt: at));
  }

  /// Applies [change] to the current state and writes it out, one at a time.
  /// [change] is handed the state as it is when its turn comes, never a
  /// snapshot taken earlier.
  Future<void> _mutate(AutoSendData Function(AutoSendData data) change, {DateTime? now}) {
    final previous = _writes;
    final mine = Completer<void>();
    _writes = mine.future;
    return previous
        .then((_) async {
          _data = _prune(change(_data), now ?? DateTime.now());
          try {
            await store.save(_data);
          } catch (e) {
            _log.warning('cannot write the auto-send queue: $e');
          }
        })
        .whenComplete(mine.complete);
  }

  AutoSendData _prune(AutoSendData data, DateTime now) {
    final cutoff = now.toUtc().subtract(maxAge);
    var pending = data.pending
        .where((e) => !e.queuedAt.toUtc().isBefore(cutoff))
        .toList(growable: false);
    // Oldest first by construction: a backlog this long means the oldest are
    // the least likely to still be wanted.
    if (pending.length > maxPending) {
      pending = pending.sublist(pending.length - maxPending);
    }
    var done = data.done;
    if (done.length > maxDone) done = done.sublist(done.length - maxDone);
    return data.copyWith(pending: pending, done: done);
  }

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.every(b.contains);
}
