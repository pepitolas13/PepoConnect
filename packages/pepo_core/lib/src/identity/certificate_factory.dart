import 'dart:math';

import 'identity.dart';
import 'x509.dart';

/// Generates fresh device identities (EC P-256 key + self-signed certificate).
class CertificateFactory {
  const CertificateFactory();

  /// Generates a new identity. Takes ~50-300 ms in pure Dart.
  ///
  /// [commonName] is shown in the certificate subject; it does not need to be
  /// unique because peers pin fingerprints, never names.
  Identity generate({String commonName = 'PepoConnect', int days = 3650}) {
    final pair = X509Encoder.generateP256KeyPair();
    final now = DateTime.now().toUtc();
    // Back-date one day so clock skew between devices never invalidates it.
    final notBefore = now.subtract(const Duration(days: 1));
    final notAfter = now.add(Duration(days: days));
    final certDer = X509Encoder.selfSignedCertificateDer(
      privateKey: pair.privateKey,
      publicKey: pair.publicKey,
      commonName: commonName,
      notBefore: notBefore,
      notAfter: notAfter,
      serial: _randomSerial(),
    );
    final keyDer = X509Encoder.pkcs8PrivateKeyDer(pair.privateKey, pair.publicKey);
    return Identity(
      certificatePem: X509Encoder.pem('CERTIFICATE', certDer),
      privateKeyPem: X509Encoder.pem('PRIVATE KEY', keyDer),
    );
  }

  /// Positive 63-bit random serial (RFC 5280 requires a positive integer).
  static BigInt _randomSerial() {
    final r = Random.secure();
    final hi = r.nextInt(1 << 31);
    final lo = r.nextInt(1 << 32);
    return (BigInt.from(hi) << 32) | BigInt.from(lo) | BigInt.one;
  }
}
