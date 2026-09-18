// Debug helper: writes a freshly generated certificate and key as PEM files.
// Usage: dart run tool/dump_identity.dart <output-dir>
import 'dart:io';

import 'package:pepo_core/src/identity/certificate_factory.dart';

void main(List<String> args) {
  final dir = Directory(args.isEmpty ? '.' : args.first)..createSync(recursive: true);
  final id = const CertificateFactory().generate(commonName: 'pepo-dump');
  File('${dir.path}/cert.pem').writeAsStringSync(id.certificatePem);
  File('${dir.path}/key.pem').writeAsStringSync(id.privateKeyPem);
  stdout.writeln('deviceId=${id.deviceId} fingerprint=${id.fingerprint}');
}
