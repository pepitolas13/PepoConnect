import 'dart:async';

/// Turns a noisy stream of "the library changed" signals into a bounded
/// number of scans that never overlap and never drop a change.
///
/// Android's MediaStore notifies several times per photo: the camera inserts
/// the row as *pending* (hidden from queries), writes the file and commits
/// the row a moment later. A scan started on the first signal cannot see the
/// photo yet, and the commit signal used to be lost when it arrived while
/// that scan was still running, so the photo only showed up with the next
/// one. Here a burst of signals becomes one scan shortly after the last of
/// them; a signal that arrives during a scan queues one more scan right
/// after it; and each burst is followed by a few delayed re-scans in case
/// the change was still invisible when the scan ran.
class RescanScheduler {
  RescanScheduler({
    required this.scan,
    this.debounce = const Duration(milliseconds: 300),
    this.settleDelays = const [Duration(milliseconds: 1500), Duration(seconds: 5)],
  });

  /// The scan. It must not throw; a throwing scan ends the current run and
  /// propagates to whoever called [run].
  final Future<void> Function() scan;

  /// Quiet time after the last signal of a burst before the scan starts.
  final Duration debounce;

  /// Re-scans after each burst, measured from the debounced scan.
  final List<Duration> settleDelays;

  Timer? _debounce;
  final List<Timer> _settle = [];
  bool _scanning = false;
  bool _dirty = false;
  int _scans = 0;

  /// Scans started so far.
  int get scans => _scans;

  /// True while a scan is running.
  bool get scanning => _scanning;

  /// One change signal. Coalesced with the other signals of the same burst.
  void signal() {
    _debounce?.cancel();
    _debounce = Timer(debounce, _fire);
  }

  void _fire() {
    _debounce = null;
    _cancelSettle();
    for (final d in settleDelays) {
      _settle.add(Timer(d, () => unawaited(run())));
    }
    unawaited(run());
  }

  /// Scans now, or queues one more scan when one is already running (the
  /// returned future then completes at once).
  Future<void> run() async {
    if (_scanning) {
      _dirty = true;
      return;
    }
    _scanning = true;
    try {
      do {
        _dirty = false;
        _scans++;
        await scan();
      } while (_dirty);
    } finally {
      _scanning = false;
    }
  }

  /// Drops the pending timers and the queued re-run. A scan in progress
  /// finishes on its own. The scheduler can be used again afterwards.
  void cancel() {
    _debounce?.cancel();
    _debounce = null;
    _cancelSettle();
    _dirty = false;
  }

  void _cancelSettle() {
    for (final t in _settle) {
      t.cancel();
    }
    _settle.clear();
  }
}
