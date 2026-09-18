import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pepo_core/pepo_core.dart';

/// Text clipboard sharing.
///
/// Outgoing: polls the local clipboard while enabled and pushes changes to
/// devices that opted in. Incoming: writes received text to the clipboard.
/// Mobile platforms only allow reading the clipboard in the foreground, so
/// there the outgoing side is driven by [sendNow] (button / app resumed).
class ClipboardSync {
  ClipboardSync(this.engine);

  final PepoEngine engine;
  Timer? _timer;
  String? _lastSeen;
  String? _lastReceived;
  StreamSubscription<EngineEvent>? _sub;
  bool _enabled = false;

  bool get enabled => _enabled;

  void start({required bool poll}) {
    _sub ??= engine.events.listen((e) {
      if (e is ClipboardReceivedEvent) _apply(e.text);
    });
    setEnabled(_enabled, poll: poll);
  }

  void setEnabled(bool value, {required bool poll}) {
    _enabled = value;
    _timer?.cancel();
    _timer = null;
    if (value && poll) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  Future<void> _tick() async {
    if (!_enabled) return;
    if (!engine.sessions.sessions.any((s) => s.isConnected && s.device.shareClipboard)) return;
    await sendNow(onlyIfChanged: true);
  }

  /// Reads the clipboard and sends its text. Returns true when something
  /// was sent.
  Future<bool> sendNow({bool onlyIfChanged = false, String? deviceId}) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty || text.length > 64 * 1024) return false;
      if (onlyIfChanged && (text == _lastSeen || text == _lastReceived)) return false;
      _lastSeen = text;
      engine.sendClipboard(text, deviceId: deviceId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _apply(String text) async {
    _lastReceived = text;
    _lastSeen = text;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}
  }

  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
  }
}
