// Throughput benchmark: TLS vs plain TCP, receiver in its own isolate.
// Usage: dart run tool/bench_tls.dart [megabytes]
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pepo_core/src/identity/certificate_factory.dart';
import 'package:pepo_core/src/identity/identity.dart';

Future<void> main(List<String> args) async {
  final mb = args.isEmpty ? 256 : int.parse(args.first);
  final id = const CertificateFactory().generate();
  for (final tls in [false, true]) {
    for (final chunk in [64 * 1024, 256 * 1024, 1024 * 1024]) {
      final mbps = await _run(id, tls: tls, chunk: chunk, bytes: mb * 1024 * 1024);
      stdout.writeln('${tls ? 'TLS  ' : 'TCP  '} chunk ${(chunk / 1024).round().toString().padLeft(4)} KiB: ${mbps.toStringAsFixed(0)} MB/s');
    }
  }
}

Future<double> _run(Identity id, {required bool tls, required int chunk, required int bytes}) async {
  final ready = ReceivePort();
  final done = ReceivePort();
  await Isolate.spawn(_receiver, [ready.sendPort, done.sendPort, tls, id.toJson()]);
  final port = await ready.first as int;
  final Socket socket;
  if (tls) {
    socket = await SecureSocket.connect('127.0.0.1', port,
        context: SecurityContext(withTrustedRoots: false),
        onBadCertificate: (c) => Identity.fingerprintOfDer(c.der) == id.fingerprint);
  } else {
    socket = await Socket.connect('127.0.0.1', port);
  }
  final block = Uint8List(chunk);
  for (var i = 0; i < block.length; i++) {
    block[i] = i & 0xFF;
  }
  final sw = Stopwatch()..start();
  await socket.addStream(() async* {
    var left = bytes;
    while (left > 0) {
      final n = left < chunk ? left : chunk;
      yield n == chunk ? block : Uint8List.sublistView(block, 0, n);
      left -= n;
    }
  }());
  await socket.flush();
  await socket.close();
  final received = await done.first as int;
  sw.stop();
  if (received != bytes) stderr.writeln('mismatch: $received != $bytes');
  return bytes / 1048576 / (sw.elapsedMicroseconds / 1e6);
}

Future<void> _receiver(List<dynamic> args) async {
  final ready = args[0] as SendPort;
  final done = args[1] as SendPort;
  final tls = args[2] as bool;
  final id = Identity.fromJson((args[3] as Map).cast<String, dynamic>());
  Stream<Socket> incoming;
  int port;
  if (tls) {
    final s = await SecureServerSocket.bind('127.0.0.1', 0, id.serverContext());
    port = s.port;
    incoming = s;
  } else {
    final s = await ServerSocket.bind('127.0.0.1', 0);
    port = s.port;
    incoming = s;
  }
  ready.send(port);
  final socket = await incoming.first;
  var total = 0;
  await for (final chunk in socket) {
    total += chunk.length;
  }
  done.send(total);
}
