import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const _hexDigits = '0123456789abcdef';

/// Lower-case hexadecimal encoding of [bytes].
String toHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(_hexDigits[(b >> 4) & 0xF]);
    sb.write(_hexDigits[b & 0xF]);
  }
  return sb.toString();
}

/// Decodes a lower/upper-case hexadecimal string.
Uint8List fromHex(String hex) {
  if (hex.length.isOdd) throw FormatException('odd hex length', hex);
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Crockford base32 (no padding). Used for human-friendly device ids.
String base32Crockford(List<int> bytes) {
  final sb = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      sb.write(_crockford[(buffer >> (bits - 5)) & 0x1F]);
      bits -= 5;
      buffer &= (1 << bits) - 1;
    }
  }
  if (bits > 0) sb.write(_crockford[(buffer << (5 - bits)) & 0x1F]);
  return sb.toString();
}

/// URL-safe base64 without padding.
String base64Url(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');

/// Decodes URL-safe base64 with or without padding.
Uint8List base64UrlDecode(String s) {
  var t = s.replaceAll('-', '+').replaceAll('_', '/');
  while (t.length % 4 != 0) {
    t += '=';
  }
  return base64Decode(t);
}

/// Cryptographically secure random bytes.
Uint8List randomBytes(int n) {
  final r = Random.secure();
  final out = Uint8List(n);
  for (var i = 0; i < n; i++) {
    out[i] = r.nextInt(256);
  }
  return out;
}

/// SHA-256 digest as bytes.
Uint8List sha256Bytes(List<int> data) => Uint8List.fromList(sha256.convert(data).bytes);

/// Constant-time comparison of two byte lists.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Concatenates byte lists into a single buffer.
Uint8List concatBytes(Iterable<List<int>> parts) {
  final b = BytesBuilder(copy: false);
  for (final p in parts) {
    b.add(p);
  }
  return b.takeBytes();
}

/// Strips the PEM armor and returns the DER bytes.
Uint8List pemToDer(String pem) {
  final body = pem
      .split(RegExp(r'\r?\n'))
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .map((l) => l.trim())
      .join();
  return base64Decode(body);
}
