import 'dart:async';

import 'package:pepo_core/src/media/rescan_scheduler.dart';
import 'package:test/test.dart';

Future<void> tick(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('RescanScheduler', () {
    test('a burst of signals becomes one scan after the quiet time', () async {
      var scans = 0;
      final s = RescanScheduler(
        scan: () async => scans++,
        debounce: const Duration(milliseconds: 40),
        settleDelays: const [],
      );
      s.signal();
      await tick(15);
      s.signal();
      await tick(15);
      s.signal();
      await tick(20);
      expect(scans, 0, reason: 'still inside the quiet time');
      await tick(40);
      expect(scans, 1);
      await tick(60);
      expect(scans, 1);
      s.cancel();
    });

    test('a signal during a scan queues one more scan instead of being lost', () async {
      final started = <int>[];
      final gate = Completer<void>();
      var n = 0;
      final s = RescanScheduler(
        scan: () async {
          started.add(++n);
          if (n == 1) await gate.future;
        },
        debounce: const Duration(milliseconds: 10),
        settleDelays: const [],
      );
      s.signal();
      await tick(20);
      expect(started, [1]);
      expect(s.scanning, isTrue);
      // The commit of a pending row lands while the first scan runs.
      s.signal();
      await tick(20);
      expect(started, [1], reason: 'never two scans at once');
      gate.complete();
      await tick(10);
      expect(started, [1, 2]);
      expect(s.scanning, isFalse);
      s.cancel();
    });

    test('run() during a scan queues one re-run at most', () async {
      final gate = Completer<void>();
      var n = 0;
      final s = RescanScheduler(
        scan: () async {
          n++;
          if (n == 1) await gate.future;
        },
        settleDelays: const [],
      );
      final first = s.run();
      await s.run();
      await s.run();
      await s.run();
      expect(n, 1);
      gate.complete();
      await first;
      await tick(5);
      expect(n, 2);
      s.cancel();
    });

    test('each burst is followed by the settle re-scans', () async {
      final at = <int>[];
      final sw = Stopwatch()..start();
      final s = RescanScheduler(
        scan: () async => at.add(sw.elapsedMilliseconds),
        debounce: const Duration(milliseconds: 10),
        settleDelays: const [Duration(milliseconds: 50), Duration(milliseconds: 120)],
      );
      s.signal();
      await tick(200);
      expect(at.length, 3);
      expect(at[1] - at[0], greaterThanOrEqualTo(45));
      expect(at[2] - at[0], greaterThanOrEqualTo(110));
      s.cancel();
    });

    test('a new burst replaces the pending settle re-scans', () async {
      var scans = 0;
      final s = RescanScheduler(
        scan: () async => scans++,
        debounce: const Duration(milliseconds: 10),
        settleDelays: const [Duration(milliseconds: 60)],
      );
      s.signal();
      await tick(30);
      expect(scans, 1);
      s.signal();
      await tick(30);
      expect(scans, 2);
      await tick(60);
      expect(scans, 3, reason: 'one settle re-scan for the second burst, not two');
      s.cancel();
    });

    test('cancel() drops the pending timers and the queued re-run', () async {
      final gate = Completer<void>();
      var n = 0;
      final s = RescanScheduler(
        scan: () async {
          n++;
          if (n == 1) await gate.future;
        },
        debounce: const Duration(milliseconds: 10),
        settleDelays: const [Duration(milliseconds: 30)],
      );
      s.signal();
      await tick(20);
      expect(n, 1);
      s.signal();
      s.cancel();
      gate.complete();
      await tick(60);
      expect(n, 1);
      // Still usable afterwards.
      s.signal();
      await tick(20);
      expect(n, 2);
      s.cancel();
    });
  });
}
