import 'dart:typed_data';

import 'package:pepo_core/src/net/auth.dart';
import 'package:pepo_core/src/pairing/qr_payload.dart';
import 'package:pepo_core/src/util/bytes.dart';
import 'package:test/test.dart';

void main() {
  test('HKDF-SHA256 matches RFC 5869 test case 1', () {
    final ikm = Uint8List.fromList(List.filled(22, 0x0b));
    final salt = fromHex('000102030405060708090a0b0c');
    final info = fromHex('f0f1f2f3f4f5f6f7f8f9');
    final okm = PepoCrypto.hkdfSha256(ikm: ikm, salt: salt, info: info, length: 42);
    expect(
      toHex(okm),
      '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865',
    );
  });

  test('pairing proofs and PSK are symmetric and bound to fingerprints', () {
    final secret = randomBytes(32);
    final nc = randomBytes(32);
    final ns = randomBytes(32);
    final p1 = PepoCrypto.pairingProof(
      secret: secret,
      label: PepoCrypto.labelPairRequest,
      nonceClient: nc,
      nonceServer: ns,
      fpClient: 'aa',
      fpServer: 'bb',
    );
    final p2 = PepoCrypto.pairingProof(
      secret: secret,
      label: PepoCrypto.labelPairRequest,
      nonceClient: nc,
      nonceServer: ns,
      fpClient: 'aa',
      fpServer: 'bb',
    );
    final p3 = PepoCrypto.pairingProof(
      secret: secret,
      label: PepoCrypto.labelPairRequest,
      nonceClient: nc,
      nonceServer: ns,
      fpClient: 'aa',
      fpServer: 'cc',
    );
    expect(PepoCrypto.verify(p1, p2), isTrue);
    expect(PepoCrypto.verify(p1, p3), isFalse);

    final pskA = PepoCrypto.derivePsk(
      secret: secret,
      nonceClient: nc,
      nonceServer: ns,
      deviceIdA: 'A',
      deviceIdB: 'B',
    );
    final pskB = PepoCrypto.derivePsk(
      secret: secret,
      nonceClient: nc,
      nonceServer: ns,
      deviceIdA: 'B',
      deviceIdB: 'A',
    );
    expect(pskA, pskB);
    expect(pskA, hasLength(32));

    final auth = PepoCrypto.authProof(
      psk: pskA,
      nonceClient: nc,
      nonceServer: ns,
      fpClient: 'aa',
      fpServer: 'bb',
      role: 'client',
    );
    final authServer = PepoCrypto.authProof(
      psk: pskA,
      nonceClient: nc,
      nonceServer: ns,
      fpClient: 'aa',
      fpServer: 'bb',
      role: 'server',
    );
    expect(PepoCrypto.verify(auth, authServer), isFalse);
    expect(PepoCrypto.verificationCode(pskA), matches(RegExp(r'^[A-Z]{4} [A-Z]{4}$')));
  });

  test('manual code secret is deterministic per host', () {
    final a = PepoCrypto.manualCodeSecret('123456', 'HOST');
    final b = PepoCrypto.manualCodeSecret('123456', 'HOST');
    final c = PepoCrypto.manualCodeSecret('123456', 'OTHER');
    expect(a, b);
    expect(a, isNot(c));
    expect(ManualCode.isValid(ManualCode.generate()), isTrue);
    expect(ManualCode.isValid('12345'), isFalse);
  });

  test('QR payload round trip and validation', () {
    final payload = QrPayload(
      deviceId: 'A' * 26,
      fingerprint: 'f' * 64,
      name: 'PC de Daniel ñ',
      addresses: ['192.168.1.20', '10.0.0.5'],
      port: 47473,
      secret: randomBytes(32),
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
    );
    final text = payload.toString();
    expect(text, startsWith('pepoconnect://pair/1?'));
    final parsed = QrPayload.tryParse(text)!;
    expect(parsed.deviceId, payload.deviceId);
    expect(parsed.fingerprint, payload.fingerprint);
    expect(parsed.name, payload.name);
    expect(parsed.addresses, payload.addresses);
    expect(parsed.port, 47473);
    expect(parsed.secret, payload.secret);
    expect(parsed.isExpired, isFalse);
    expect(parsed.expiresAt.difference(payload.expiresAt).inSeconds.abs(), lessThan(2));

    expect(QrPayload.tryParse('https://example.com'), isNull);
    expect(QrPayload.tryParse('pepoconnect://pair/1?id=short'), isNull);
    expect(QrPayload.tryParse('not a uri at all ://'), isNull);
    final expired = QrPayload.tryParse(
      payload
          .toUri()
          .replace(queryParameters: {...payload.toUri().queryParameters, 'e': '1000'})
          .toString(),
    )!;
    expect(expired.isExpired, isTrue);
  });
}
