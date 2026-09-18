import 'dart:typed_data';

import 'native_bulk.dart';

/// How to reach a peer on the fast lane for one transfer: the engine, the
/// session key material, and who opens the TCP connection.
class NativeRoute {
  const NativeRoute({
    required this.native,
    required this.sid,
    required this.key,
    required this.weConnect,
    required this.host,
    required this.port,
  });

  final NativeBulk native;

  /// 16-byte session id (both sides derive it from the session token).
  final Uint8List sid;

  /// 32-byte session key (HKDF of the PSK and the session token).
  final Uint8List key;

  /// True when this side dials the peer's bulk listener (the side that
  /// opened the control channel always dials).
  final bool weConnect;

  /// Peer address and bulk port, used when [weConnect].
  final String host;
  final int port;
}
