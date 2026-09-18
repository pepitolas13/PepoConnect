/// PepoConnect core library (pure Dart, no Flutter dependency).
library;

export 'src/discovery/discovery.dart';
export 'src/discovery/udp_beacon.dart' show UdpBeacon, defaultBeaconPort, localIPv4Addresses;
export 'src/engine/engine_config.dart';
export 'src/engine/engine_events.dart';
export 'src/engine/pepo_engine.dart';
export 'src/identity/certificate_factory.dart';
export 'src/identity/identity.dart';
export 'src/identity/identity_store.dart';
export 'src/media/gallery_client.dart';
export 'src/media/image_ops.dart';
export 'src/media/media_server.dart' show MediaServer, DeletePolicy;
export 'src/media/media_source.dart';
export 'src/media/media_source_fs.dart';
export 'src/net/handshake.dart' show HandshakeException, NotPairedException;
export 'src/net/peer_connection.dart' show PeerError, PeerClosedException;
export 'src/net/peer_listener.dart' show defaultListenPort;
export 'src/net/session.dart'
    show DeviceStore, MemoryDeviceStore, SessionState, SessionManager, PeerSession;
export 'src/pairing/pairing_session.dart' show PairingMode;
export 'src/pairing/qr_payload.dart';
export 'src/protocol/message_types.dart';
export 'src/protocol/models.dart';
export 'src/share/guest_share_server.dart';
export 'src/transfer/folder_layout.dart';
export 'src/transfer/name_sanitizer.dart';
export 'src/transfer/transfer_engine.dart' show TransferEngine, OfferPolicy, DestinationResolver;
export 'src/transfer/transfer_record.dart';
export 'src/util/bytes.dart' show toHex, fromHex, base64Url, base64UrlDecode, randomBytes;
export 'src/version.dart';
