import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// Minimal, spec-strict DER encoders for what PepoConnect needs:
/// a self-signed EC P-256 certificate (RFC 5280 + RFC 5758) and a PKCS#8
/// private key (RFC 5958 / RFC 5915).
///
/// Written by hand because BoringSSL (used by `dart:io`) rejects the output of
/// generic Dart libraries that emit a NULL parameter after `ecdsa-with-SHA256`
/// or sloppy KeyUsage bit strings.
class X509Encoder {
  const X509Encoder._();

  static const _oidEcdsaWithSha256 = '1.2.840.10045.4.3.2';
  static const _oidIdEcPublicKey = '1.2.840.10045.2.1';
  static const _oidPrime256v1 = '1.2.840.10045.3.1.7';
  static const _oidCommonName = '2.5.4.3';
  static const _oidOrganization = '2.5.4.10';

  /// Generates a P-256 key pair using a Fortuna PRNG seeded from
  /// `Random.secure()`.
  static AsymmetricKeyPair<ECPublicKey, ECPrivateKey> generateP256KeyPair() {
    final rnd = secureRandom();
    final gen = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(ECCurve_secp256r1()), rnd));
    return gen.generateKeyPair();
  }

  /// A [SecureRandom] seeded with 32 bytes from the platform CSPRNG.
  static SecureRandom secureRandom() {
    final seed = Uint8List(32);
    final r = Random.secure();
    for (var i = 0; i < seed.length; i++) {
      seed[i] = r.nextInt(256);
    }
    return FortunaRandom()..seed(KeyParameter(seed));
  }

  /// DER of a self-signed v3 certificate signed with ECDSA-SHA256.
  static Uint8List selfSignedCertificateDer({
    required ECPrivateKey privateKey,
    required ECPublicKey publicKey,
    required String commonName,
    required DateTime notBefore,
    required DateTime notAfter,
    required BigInt serial,
    String organization = 'PepoConnect',
  }) {
    final name = _name(commonName, organization);
    final tbs = ASN1Sequence(
      elements: [
        ASN1Sequence(elements: [ASN1Integer(BigInt.two)], tag: 0xA0),
        ASN1Integer(serial),
        _algorithmEcdsaSha256(),
        name,
        ASN1Sequence(elements: [_time(notBefore), _time(notAfter)]),
        _name(commonName, organization),
        _subjectPublicKeyInfo(publicKey),
      ],
    );
    final tbsDer = tbs.encode();
    final signature = _ecdsaSign(privateKey, tbsDer);
    final cert = ASN1Sequence(
      elements: [
        ASN1Sequence.fromBytes(tbsDer),
        _algorithmEcdsaSha256(),
        ASN1BitString(stringValues: signature),
      ],
    );
    return cert.encode();
  }

  /// DER of a PKCS#8 `PrivateKeyInfo` wrapping an RFC 5915 `ECPrivateKey`.
  static Uint8List pkcs8PrivateKeyDer(ECPrivateKey privateKey, ECPublicKey publicKey) {
    final ecPrivateKey = ASN1Sequence(
      elements: [
        ASN1Integer(BigInt.one),
        ASN1OctetString(octets: _bigIntToFixed(privateKey.d!, 32)),
        ASN1Sequence(
          elements: [ASN1BitString(stringValues: _uncompressedPoint(publicKey))],
          tag: 0xA1,
        ),
      ],
    );
    final info = ASN1Sequence(
      elements: [
        ASN1Integer(BigInt.zero),
        ASN1Sequence(
          elements: [
            ASN1ObjectIdentifier.fromIdentifierString(_oidIdEcPublicKey),
            ASN1ObjectIdentifier.fromIdentifierString(_oidPrime256v1),
          ],
        ),
        ASN1OctetString(octets: ecPrivateKey.encode()),
      ],
    );
    return info.encode();
  }

  /// Parses a PKCS#8 DER produced by [pkcs8PrivateKeyDer] back into keys.
  static AsymmetricKeyPair<ECPublicKey, ECPrivateKey> keyPairFromPkcs8(Uint8List der) {
    final info = ASN1Sequence.fromBytes(der);
    final wrapped = info.elements![2] as ASN1OctetString;
    final ecKey = ASN1Sequence.fromBytes(wrapped.octets!);
    final d = _bytesToBigInt((ecKey.elements![1] as ASN1OctetString).octets!);
    final curve = ECCurve_secp256r1();
    final priv = ECPrivateKey(d, curve);
    final q = curve.G * d;
    final pub = ECPublicKey(q, curve);
    return AsymmetricKeyPair(pub, priv);
  }

  /// PEM armor with 64-column base64 lines.
  static String pem(String label, Uint8List der) {
    final b64 = base64Encode(der);
    final sb = StringBuffer('-----BEGIN $label-----\n');
    for (var i = 0; i < b64.length; i += 64) {
      sb.writeln(b64.substring(i, min(i + 64, b64.length)));
    }
    sb.write('-----END $label-----\n');
    return sb.toString();
  }

  // ---------------------------------------------------------------------------

  static ASN1Sequence _algorithmEcdsaSha256() => ASN1Sequence(
    elements: [
      // RFC 5758 §3.2: parameters MUST be absent (no NULL).
      ASN1ObjectIdentifier.fromIdentifierString(_oidEcdsaWithSha256),
    ],
  );

  static ASN1Sequence _name(String cn, String org) => ASN1Sequence(
    elements: [
      ASN1Set(
        elements: [
          ASN1Sequence(
            elements: [
              ASN1ObjectIdentifier.fromIdentifierString(_oidCommonName),
              ASN1UTF8String(utf8StringValue: cn),
            ],
          ),
        ],
      ),
      ASN1Set(
        elements: [
          ASN1Sequence(
            elements: [
              ASN1ObjectIdentifier.fromIdentifierString(_oidOrganization),
              ASN1UTF8String(utf8StringValue: org),
            ],
          ),
        ],
      ),
    ],
  );

  static ASN1Object _time(DateTime t) {
    final utc = t.toUtc();
    // RFC 5280 §4.1.2.5: UTCTime through 2049, GeneralizedTime from 2050.
    if (utc.year >= 2050) return ASN1GeneralizedTime(utc);
    return ASN1UtcTime(utc);
  }

  static ASN1Sequence _subjectPublicKeyInfo(ECPublicKey pub) => ASN1Sequence(
    elements: [
      ASN1Sequence(
        elements: [
          ASN1ObjectIdentifier.fromIdentifierString(_oidIdEcPublicKey),
          ASN1ObjectIdentifier.fromIdentifierString(_oidPrime256v1),
        ],
      ),
      ASN1BitString(stringValues: _uncompressedPoint(pub)),
    ],
  );

  static Uint8List _uncompressedPoint(ECPublicKey pub) =>
      Uint8List.fromList(pub.Q!.getEncoded(false));

  static Uint8List _ecdsaSign(ECPrivateKey key, Uint8List data) {
    final signer = Signer('SHA-256/ECDSA') as ECDSASigner;
    signer.init(true, ParametersWithRandom(PrivateKeyParameter<ECPrivateKey>(key), secureRandom()));
    final sig = signer.generateSignature(data) as ECSignature;
    return ASN1Sequence(elements: [ASN1Integer(sig.r), ASN1Integer(sig.s)]).encode();
  }

  static Uint8List _bigIntToFixed(BigInt v, int length) {
    var hex = v.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    final raw = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < raw.length; i++) {
      raw[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    if (raw.length > length) {
      throw ArgumentError('value does not fit in $length bytes');
    }
    final out = Uint8List(length);
    out.setRange(length - raw.length, length, raw);
    return out;
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }
}
