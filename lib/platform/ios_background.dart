import 'pepo_native.dart';

/// What the iOS side reports about the background engine.
class IosBackgroundState {
  const IosBackgroundState({
    this.running = false,
    this.playing = false,
    this.held = false,
    this.refresh = 'unknown',
    this.startedAt,
  });

  /// The engine is meant to be running.
  final bool running;

  /// The silent loop really is playing. Running without playing means iOS
  /// took the audio session away and the watchdog has not won it back yet.
  final bool playing;

  /// A `beginBackgroundTask` assertion is held (a transfer is in flight).
  final bool held;

  /// `available`, `denied`, `restricted` or `unknown`: the system switch for
  /// Background App Refresh, which gates the `BGTask` safety net.
  final String refresh;

  /// When the loop started. It resets with the process, so how long it has
  /// been running is the phone's own proof that iOS never suspended it.
  final DateTime? startedAt;

  bool get healthy => running && playing;

  static const IosBackgroundState off = IosBackgroundState();

  factory IosBackgroundState.fromMap(Map<String, Object?> map) {
    final started = map['startedAt'];
    return IosBackgroundState(
      running: map['running'] as bool? ?? false,
      playing: map['playing'] as bool? ?? false,
      held: map['held'] as bool? ?? false,
      refresh: map['refresh'] as String? ?? 'unknown',
      startedAt: started is int ? DateTime.fromMillisecondsSinceEpoch(started) : null,
    );
  }
}

/// The iOS counterpart of the Android foreground service: what keeps the
/// engine in this isolate running once PepoConnect leaves the screen.
///
/// iOS never wakes a suspended app for a new photo — no API does that — so
/// the only way a photo leaves the phone on its own is for the process not to
/// be suspended in the first place. [start] plays an inaudible loop under the
/// `audio` background mode to get exactly that, and everything else (the
/// photo library observer, the control socket, the transfers) keeps working
/// untouched.
///
/// What it does not survive: the app being closed from the app switcher, or a
/// reboot. Then the pending photos wait in the auto-send queue until the app
/// is opened again, or until iOS grants one of the `BGTask`s.
class IosBackground {
  const IosBackground._();

  static bool get isSupported => PepoNative.isIos;

  /// Starts the keep-alive engine. False when the audio session refused,
  /// which the watchdog on the native side will keep retrying.
  static Future<bool> start() async {
    if (!isSupported) return false;
    return PepoNative.keepAliveStart();
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    await PepoNative.keepAliveStop();
  }

  /// Holds the process up for the ~30 s iOS grants on request. Cheap enough
  /// to leave held for as long as a transfer runs.
  static Future<void> hold(bool on) async {
    if (!isSupported) return;
    await PepoNative.backgroundHold(on);
  }

  static Future<IosBackgroundState> status() async {
    if (!isSupported) return IosBackgroundState.off;
    final raw = await PepoNative.backgroundStatus();
    return raw == null ? IosBackgroundState.off : IosBackgroundState.fromMap(raw);
  }
}
