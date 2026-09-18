import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../util/bytes.dart';

/// Long-term cryptographic identity of a device: an EC P-256 key pair and a
/// self-signed X.509 certificate used for TLS.
///
/// The [deviceId] and [fingerprint] are both derived from the certificate DER
/// so any peer can recompute them from what it sees on the wire.
@immutable
class Identity {
  Identity({
    required this.certificatePem,
    required this.privateKeyPem,
  })  : certificateDer = pemToDer(certificatePem),
        fingerprint = toHex(sha256Bytes(pemToDer(certificatePem))),
        deviceId = deviceIdFromDer(pemToDer(certificatePem));

  /// PEM encoded certificate (`-----BEGIN CERTIFICATE-----`).
  final String certificatePem;

  /// PEM encoded PKCS#8 private key (`-----BEGIN PRIVATE KEY-----`).
  final String privateKeyPem;

  /// DER bytes of the certificate.
  final Uint8List certificateDer;

  /// SHA-256 of the certificate DER, lower-case hex (64 chars).
  final String fingerprint;

  /// 26-char Crockford base32 id derived from the certificate.
  final String deviceId;

  /// Short human readable form, e.g. `PEPO-3F2K-9QW1`.
  String get shortId => shortIdOf(deviceId);

  /// Creates a [SecurityContext] able to serve TLS with this identity.
  SecurityContext serverContext() {
    final ctx = SecurityContext(withTrustedRoots: false);
    ctx.useCertificateChainBytes(utf8.encode(certificatePem));
    ctx.usePrivateKeyBytes(utf8.encode(privateKeyPem));
    return ctx;
  }

  Map<String, dynamic> toJson() => {
        'certificatePem': certificatePem,
        'privateKeyPem': privateKeyPem,
      };

  factory Identity.fromJson(Map<String, dynamic> json) => Identity(
        certificatePem: json['certificatePem'] as String,
        privateKeyPem: json['privateKeyPem'] as String,
      );

  /// Device id from a certificate DER: first 26 chars of Crockford base32 of
  /// its SHA-256.
  static String deviceIdFromDer(Uint8List der) =>
      base32Crockford(sha256Bytes(der)).substring(0, 26);

  /// Fingerprint (hex SHA-256) from a certificate DER.
  static String fingerprintOfDer(Uint8List der) => toHex(sha256Bytes(der));

  /// `PEPO-XXXX-XXXX` from a device id.
  static String shortIdOf(String deviceId) =>
      'PEPO-${deviceId.substring(0, 4)}-${deviceId.substring(4, 8)}';

  /// Short (16 hex) fingerprint used in discovery records.
  static String shortFingerprint(String fingerprint) =>
      fingerprint.substring(0, 16);
}
