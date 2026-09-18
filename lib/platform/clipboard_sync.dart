import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pepo_core/pepo_core.dart';

import '../state/engine_providers.dart';

/// Why a clipboard push did or did not happen.
enum ClipboardSendReason { sent, unchanged, empty, noTarget }

class ClipboardSendResult {
  const ClipboardSendResult(this.reason, {this.sentTo = const []});

  final ClipboardSendReason reason;

  /// Names of the devices the text went to.
  final List<String> sentTo;

  bool get sent => reason == ClipboardSendReason.sent;
}

/// Text clipboard sharing.
///
/// Outgoing: on desktop, polls the local clipboard while enabled and pushes
/// changes to the devices that opted in. Mobile platforms only allow reading
/// the clipboard in the foreground, so there the outgoing side is driven by
/// [sendNow] (app resumed, device connected, "Send clipboard" row) and by
/// [sendText] (share sheet, Android quick tile / shortcut). Incoming: writes
/// received text to the clipboard.
class ClipboardSync {
  ClipboardSync(this.engine);

  final PepoEngine engine;
  Timer? _timer;
  String? _lastSeen;
  String? _lastReceived;
  String? _lastPushed;
  DateTime? _lastPushedAt;
  ({String text, DateTime at})? _pending;
  StreamSubscription<EngineEvent>? _sub;
  bool _enabled = false;

  static const maxLength = 64 * 1024;

  /// Text handed over while nobody was connected waits this long.
  static const pendingTtl = Duration(minutes: 2);

  /// The native bridge and its fallback can both deliver the same text.
  static const _dedupeWindow = Duration(seconds: 5);
  static const _readRetryGap = Duration(milliseconds: 250);

  bool get enabled => _enabled;

  /// A connected device that receives our clipboard exists.
  bool get hasTargets =>
      engine.sessions.sessions.any((s) => s.isConnected && s.device.shareClipboard);

  /// Text waiting for a device to connect.
  bool get hasPending => _pending != null;

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
    if (!_enabled || !hasTargets) return;
    await sendNow(onlyIfChanged: true);
  }

  /// Reads the clipboard and sends its text. With [onlyIfChanged] the text
  /// last sent or received is skipped. [retries] re-reads a clipboard that
  /// came back empty (Android only grants access once the window has focus,
  /// which can lag the resume callback by a few frames).
  Future<ClipboardSendResult> sendNow({bool onlyIfChanged = false, int retries = 0}) async {
    if (!hasTargets) return const ClipboardSendResult(ClipboardSendReason.noTarget);
    final text = await _read(retries);
    if (text == null) return const ClipboardSendResult(ClipboardSendReason.empty);
    if (onlyIfChanged && (text == _lastSeen || text == _lastReceived)) {
      return const ClipboardSendResult(ClipboardSendReason.unchanged);
    }
    return _push(text);
  }

  /// Sends [text] that another path read for us (share sheet, quick tile).
  /// When no device is connected it is kept and sent by [flushPending].
  Future<ClipboardSendResult> sendText(String text) async {
    if (text.isEmpty || text.length > maxLength) {
      return const ClipboardSendResult(ClipboardSendReason.empty);
    }
    final at = _lastPushedAt;
    if (text == _lastPushed && at != null && DateTime.now().difference(at) < _dedupeWindow) {
      return const ClipboardSendResult(ClipboardSendReason.unchanged);
    }
    if (!hasTargets) {
      _pending = (text: text, at: DateTime.now());
      return const ClipboardSendResult(ClipboardSendReason.noTarget);
    }
    return _push(text);
  }

  /// Sends the text kept by [sendText] now that a device may be connected.
  /// Null when there was nothing (fresh) to send.
  ClipboardSendResult? flushPending() {
    final pending = _pending;
    if (pending == null) return null;
    if (DateTime.now().difference(pending.at) > pendingTtl) {
      _pending = null;
      return null;
    }
    if (!hasTargets) return null;
    return _push(pending.text);
  }

  Future<String?> _read(int retries) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
        if (text != null && text.isNotEmpty) {
          return text.length > maxLength ? null : text;
        }
      } catch (_) {
        // Clipboard not readable right now (no focus, odd content).
      }
      if (attempt >= retries) return null;
      await Future<void>.delayed(_readRetryGap);
    }
  }

  ClipboardSendResult _push(String text) {
    final sentTo = engine.sendClipboard(text);
    if (sentTo.isEmpty) return const ClipboardSendResult(ClipboardSendReason.noTarget);
    // Only remember what actually left, so a text that found nobody
    // connected is sent on the next chance.
    _lastSeen = text;
    _lastPushed = text;
    _lastPushedAt = DateTime.now();
    _pending = null;
    return ClipboardSendResult(ClipboardSendReason.sent, sentTo: sentTo);
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

/// The app's clipboard sync (started by `AppServices`).
final clipboardSyncProvider = Provider<ClipboardSync>((ref) {
  final sync = ClipboardSync(ref.watch(engineProvider));
  ref.onDispose(sync.dispose);
  return sync;
});
