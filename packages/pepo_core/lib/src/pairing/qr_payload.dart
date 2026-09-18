import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../util/bytes.dart';

/// Contents of the pairing QR code / deep link:
/// `pepoconnect://pair/1?id=…&fp=…&n=…&a=ip1,ip2&p=47473&s=<secret>&e=<epoch>`
@immutable
class QrPayload {
  const QrPayload({
    required this.deviceId,
    required this.fingerprint,
    required this.name,
    required this.addresses,
    required this.port,
    required this.secret,
    required this.expiresAt,
  });

  static const scheme = 'pepoconnect';
  static const version = 1;

  final String deviceId;
  final String fingerprint;
  final String name;
  final List<String> addresses;
  final int port;
  final Uint8List secret;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Uri toUri() => Uri(
        scheme: scheme,
        host: 'pair',
        path: '/$version',
        queryParameters: {
          'id': deviceId,
          'fp': fingerprint,
          'n': name,
          'a': addresses.join(','),
          'p': '$port',
          's': base64Url(secret),
          'e': '${expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000}',
        },
      );

  @override
  String toString() => toUri().toString();

  /// Parses a scanned/pasted payload. Returns null when it is not a
  /// PepoConnect pairing link.
  static QrPayload? tryParse(String text) {
    final Uri uri;
    try {
      uri = Uri.parse(text.trim());
    } on FormatException {
      return null;
    }
    if (uri.scheme != scheme || uri.host != 'pair') return null;
    if (uri.path != '/$version' && uri.path != '$version') return null;
    final q = uri.queryParameters;
    final id = q['id'];
    final fp = q['fp'];
    final s = q['s'];
    final p = int.tryParse(q['p'] ?? '');
    final e = int.tryParse(q['e'] ?? '');
    if (id == null || id.length != 26) return null;
    if (fp == null || fp.length != 64) return null;
    if (s == null || p == null || e == null) return null;
    final Uint8List secret;
    try {
      secret = base64UrlDecode(s);
    } on FormatException {
      return null;
    }
    if (secret.length < 16) return null;
    final addresses = (q['a'] ?? '')
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    return QrPayload(
      deviceId: id,
      fingerprint: fp,
      name: q['n'] ?? '',
      addresses: addresses,
      port: p,
      secret: secret,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(e * 1000, isUtc: true),
    );
  }
}

/// Six-digit code for pairing without a camera (PC↔PC).
class ManualCode {
  const ManualCode._();

  static String generate() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  static bool isValid(String code) => RegExp(r'^\d{6}$').hasMatch(code);
}
