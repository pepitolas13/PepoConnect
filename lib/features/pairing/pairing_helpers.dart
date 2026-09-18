import 'dart:async';
import 'dart:io';

import 'package:pepo_core/pepo_core.dart';

import '../../shared/i18n/l10n.dart';

/// Plain-language message for a failed pairing. [codeFlow] tells a rejected
/// proof apart: a wrong six-digit code versus a QR link that was already
/// used or expired on the PC.
String describePairingError(Object error, AppLocalizations t, {bool codeFlow = false}) {
  if (error is NotPairedException) return t.errorNotPaired;
  if (error is HandshakeException) {
    if (error.message.contains('identity changed')) return t.pairIdentityChanged;
    return switch (error.code) {
      ErrorCode.timeout => t.pairLinkExpired,
      ErrorCode.badRequest => t.pairNotACode,
      ErrorCode.rejected ||
      ErrorCode.unauthorized => codeFlow ? t.pairWrongCode : t.pairLinkExpired,
      _ => t.pairFailedBody,
    };
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is PeerClosedException ||
      error is HandshakeException) {
    return t.pairPcNotFound;
  }
  if (error is FormatException || error is ArgumentError) return t.pairNotACode;
  return t.pairFailedBody;
}

/// `192.168.1.20:47473`, `192.168.1.20`, `[fe80::1]:47473` or a bare IPv6.
/// Null when the text is not usable; a missing port means "the default".
({String host, int? port})? parseHostPort(String input) {
  final text = input.trim();
  if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;
  if (text.startsWith('[')) {
    final end = text.indexOf(']');
    if (end < 2) return null;
    final host = text.substring(1, end);
    final rest = text.substring(end + 1);
    if (rest.isEmpty) return (host: host, port: null);
    if (!rest.startsWith(':')) return null;
    final port = _port(rest.substring(1));
    return port == null ? null : (host: host, port: port);
  }
  final first = text.indexOf(':');
  final last = text.lastIndexOf(':');
  if (first < 0) return (host: text, port: null);
  // More than one colon and no brackets: a bare IPv6 address.
  if (first != last) return (host: text, port: null);
  final host = text.substring(0, last);
  final port = _port(text.substring(last + 1));
  if (host.isEmpty || port == null) return null;
  return (host: host, port: port);
}

int? _port(String text) {
  final port = int.tryParse(text);
  if (port == null || port < 1 || port > 65535) return null;
  return port;
}

/// Human name of a wire platform for the discovered-devices list.
String platformLabel(DevicePlatform platform) => switch (platform) {
  DevicePlatform.windows => 'Windows',
  DevicePlatform.linux => 'Linux',
  DevicePlatform.android => 'Android',
  DevicePlatform.ios => 'iOS',
  DevicePlatform.macos => 'macOS',
  DevicePlatform.unknown => '',
};

/// `123456` → `123 456`, easier to read out loud.
String groupCode(String code) =>
    code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
