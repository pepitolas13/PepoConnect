import 'dart:convert';
import 'dart:io';

import 'package:pepo_core/src/identity/certificate_factory.dart';
import 'package:pepo_core/src/identity/identity.dart';
import 'package:test/test.dart';

/// T1: BoringSSL must accept the pure-Dart generated EC certificate and key,
/// and the client must be able to pin the server by fingerprint.
void main() {
  late Identity server;
  late Identity client;

  setUpAll(() {
    final sw = Stopwatch()..start();
    server = const CertificateFactory().generate(commonName: 'pepo-server');
    client = const CertificateFactory().generate(commonName: 'pepo-client');
    // ignore: avoid_print
    print('generated 2 identities in ${sw.elapsedMilliseconds} ms');
  });

  test('identity derives stable id and fingerprint', () {
    expect(server.fingerprint, hasLength(64));
    expect(server.deviceId, hasLength(26));
    expect(server.shortId, startsWith('PEPO-'));
    expect(server.deviceId, isNot(client.deviceId));
    final again = Identity.fromJson(server.toJson());
    expect(again.deviceId, server.deviceId);
    expect(again.fingerprint, server.fingerprint);
    expect(server.privateKeyPem, contains('BEGIN PRIVATE KEY'));
    expect(server.certificatePem, contains('BEGIN CERTIFICATE'));
  });

  test('TLS loopback with pinned self-signed certificate', () async {
    final listener = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      server.serverContext(),
    );
    addTearDown(listener.close);

    final serverDone = listener.first.then((socket) async {
      final data = await socket.first;
      socket.add(utf8.encode('echo:${utf8.decode(data)}'));
      await socket.flush();
      await socket.close();
    });

    String? seenFingerprint;
    final socket = await SecureSocket.connect(
      InternetAddress.loopbackIPv4,
      listener.port,
      context: SecurityContext(withTrustedRoots: false),
      onBadCertificate: (cert) {
        seenFingerprint = Identity.fingerprintOfDer(cert.der);
        return seenFingerprint == server.fingerprint;
      },
      timeout: const Duration(seconds: 5),
    );
    expect(seenFingerprint, server.fingerprint);
    expect(socket.selectedProtocol, isNull);
    socket.add(utf8.encode('hola'));
    await socket.flush();
    final reply = utf8.decode(await socket.fold<List<int>>([], (a, b) => a..addAll(b)));
    expect(reply, 'echo:hola');
    await serverDone;
  });

  test('client rejects a server with a different certificate', () async {
    final listener = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      client.serverContext(), // wrong identity on purpose
    );
    addTearDown(listener.close);
    listener.listen((s) => s.destroy());
    await expectLater(
      SecureSocket.connect(
        InternetAddress.loopbackIPv4,
        listener.port,
        context: SecurityContext(withTrustedRoots: false),
        onBadCertificate: (cert) =>
            Identity.fingerprintOfDer(cert.der) == server.fingerprint,
      ),
      throwsA(isA<HandshakeException>()),
    );
  });
}
