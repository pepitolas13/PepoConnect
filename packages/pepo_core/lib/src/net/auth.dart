import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../util/bytes.dart';

/// Key derivation and proof primitives of the PepoConnect protocol.
///
/// Everything is HMAC-SHA256 based (RFC 2104 / RFC 5869). The transport itself
/// is TLS; these primitives only prove possession of the pairing secret or the
/// long-term PSK, bound to the TLS certificates of both ends.
class PepoCrypto {
  const PepoCrypto._();

  static const labelPairRequest = 'pepo-pair-v1';
  static const labelPairAccept = 'pepo-pair-acc-v1';
  static const labelAuth = 'pepo-auth-v1';
  static const labelPsk = 'pepo-psk-v1';
  static const labelManualCode = 'pepo-code';

  /// HMAC-SHA256.
  static Uint8List hmacSha256(List<int> key, List<int> data) =>
      Uint8List.fromList(Hmac(sha256, key).convert(data).bytes);

  /// HKDF-SHA256 extract + expand (RFC 5869).
  static Uint8List hkdfSha256({
    required List<int> ikm,
    required List<int> salt,
    required List<int> info,
    int length = 32,
  }) {
    final prk = hmacSha256(salt.isEmpty ? Uint8List(32) : salt, ikm);
    final out = BytesBuilder(copy: false);
    var previous = <int>[];
    var counter = 1;
    while (out.length < length) {
      previous = hmacSha256(prk, [...previous, ...info, counter]);
      out.add(previous);
      counter++;
    }
    return Uint8List.sublistView(out.takeBytes(), 0, length);
  }

  /// Proof that a peer knows [secret], bound to both nonces and both TLS
  /// certificate fingerprints. [label] selects request vs accept direction.
  static Uint8List pairingProof({
    required List<int> secret,
    required String label,
    required List<int> nonceClient,
    required List<int> nonceServer,
    required String fpClient,
    required String fpServer,
  }) => hmacSha256(
    secret,
    concatBytes([
      utf8.encode(label),
      nonceClient,
      nonceServer,
      utf8.encode(fpClient),
      utf8.encode(fpServer),
    ]),
  );

  /// Long-term pre-shared key derived at pairing time. Symmetric in the
  /// device ids so both sides compute the same value.
  static Uint8List derivePsk({
    required List<int> secret,
    required List<int> nonceClient,
    required List<int> nonceServer,
    required String deviceIdA,
    required String deviceIdB,
  }) {
    final ids = [deviceIdA, deviceIdB]..sort();
    return hkdfSha256(
      ikm: secret,
      salt: concatBytes([nonceClient, nonceServer]),
      info: utf8.encode('$labelPsk${ids[0]}${ids[1]}'),
    );
  }

  /// Session authentication proof. [role] is `client` or `server`.
  static Uint8List authProof({
    required List<int> psk,
    required List<int> nonceClient,
    required List<int> nonceServer,
    required String fpClient,
    required String fpServer,
    required String role,
  }) => hmacSha256(
    psk,
    concatBytes([
      utf8.encode(labelAuth),
      nonceClient,
      nonceServer,
      utf8.encode(fpClient),
      utf8.encode(fpServer),
      utf8.encode(role),
    ]),
  );

  /// Pairing secret derived from a 6-digit manual code shown by the host.
  static Uint8List manualCodeSecret(String code, String hostDeviceId) => hkdfSha256(
    ikm: utf8.encode(code),
    salt: utf8.encode(labelManualCode),
    info: utf8.encode(hostDeviceId),
  );

  /// Constant-time equality.
  static bool verify(List<int> a, List<int> b) => constantTimeEquals(a, b);

  static const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ';

  /// 8-letter human verification code shown on both screens after pairing,
  /// e.g. `GCGJ GSCX`, derived from the PSK.
  static String verificationCode(List<int> psk) {
    final digest = sha256Bytes([...utf8.encode('pepo-verify'), ...psk]);
    final sb = StringBuffer();
    for (var i = 0; i < 8; i++) {
      if (i == 4) sb.write(' ');
      sb.write(_codeAlphabet[digest[i] % _codeAlphabet.length]);
    }
    return sb.toString();
  }
}
