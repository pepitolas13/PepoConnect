import 'dart:async';
import 'dart:typed_data';

import '../net/auth.dart';
import '../util/bytes.dart';
import 'qr_payload.dart';

/// How a pairing session was started.
enum PairingMode { qr, manualCode }

/// A pending invitation shown by the listening device (QR or 6-digit code).
class PairingSession {
  PairingSession._({required this.mode, required this.secret, required this.expiresAt, this.code});

  final PairingMode mode;
  final Uint8List secret;
  final DateTime expiresAt;

  /// Six digits, only for [PairingMode.manualCode].
  final String? code;
  bool consumed = false;
  int failures = 0;

  bool get isExpired => consumed || DateTime.now().isAfter(expiresAt);

  Duration get remaining => expiresAt.difference(DateTime.now());
}

/// Owns the currently active pairing invitation of a listener.
class PairingSessions {
  PairingSessions({this.validity = const Duration(minutes: 2)});

  final Duration validity;
  PairingSession? _active;
  final _events = StreamController<PairingSession?>.broadcast();

  /// Emits whenever the active session changes (new, consumed, cancelled).
  Stream<PairingSession?> get changes => _events.stream;

  PairingSession? get active {
    final a = _active;
    if (a != null && a.isExpired) {
      _active = null;
      _events.add(null);
      return null;
    }
    return a;
  }

  /// Starts a QR pairing invitation with a fresh random secret.
  PairingSession startQr() {
    final s = PairingSession._(
      mode: PairingMode.qr,
      secret: randomBytes(32),
      expiresAt: DateTime.now().add(validity),
    );
    _active = s;
    _events.add(s);
    return s;
  }

  /// Starts a manual-code invitation bound to [hostDeviceId].
  PairingSession startManualCode(String hostDeviceId) {
    final code = ManualCode.generate();
    final s = PairingSession._(
      mode: PairingMode.manualCode,
      secret: PepoCrypto.manualCodeSecret(code, hostDeviceId),
      expiresAt: DateTime.now().add(validity),
      code: code,
    );
    _active = s;
    _events.add(s);
    return s;
  }

  void cancel() {
    _active = null;
    _events.add(null);
  }

  /// Marks the session as used (single use).
  void consume(PairingSession s) {
    s.consumed = true;
    if (identical(_active, s)) {
      _active = null;
      _events.add(null);
    }
  }

  /// A wrong proof: manual codes allow a single attempt; QR sessions allow a
  /// few (a scanner may retry) before being invalidated.
  void recordFailure(PairingSession s, String from) {
    s.failures++;
    final limit = s.mode == PairingMode.manualCode ? 1 : 5;
    if (s.failures >= limit) consume(s);
  }

  /// Builds the QR payload for an active QR session.
  QrPayload payloadFor(
    PairingSession s, {
    required String deviceId,
    required String fingerprint,
    required String name,
    required List<String> addresses,
    required int port,
  }) => QrPayload(
    deviceId: deviceId,
    fingerprint: fingerprint,
    name: name,
    addresses: addresses,
    port: port,
    secret: s.secret,
    expiresAt: s.expiresAt,
  );

  void dispose() => _events.close();
}
