import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../discovery/discovery.dart';
import '../discovery/udp_beacon.dart';
import '../identity/identity.dart';
import '../identity/identity_store.dart';
import '../native/native_bulk.dart';
import '../media/gallery_client.dart';
import '../media/media_server.dart';
import '../media/media_source.dart';
import '../media/media_source_fs.dart';
import '../net/frame.dart';
import '../net/handshake.dart';
import '../net/peer_connection.dart';
import '../net/session.dart';
import '../pairing/pairing_session.dart';
import '../pairing/qr_payload.dart';
import '../protocol/message_types.dart';
import '../protocol/models.dart';
import '../share/guest_share_server.dart';
import '../transfer/folder_layout.dart';
import '../transfer/transfer_engine.dart';
import '../transfer/transfer_record.dart';
import 'engine_config.dart';
import 'engine_events.dart';

final _log = Logger('pepo.engine');

/// A paired device together with its live connection state.
class DeviceView {
  const DeviceView({
    required this.device,
    required this.connected,
    required this.connecting,
    required this.status,
    this.connectedAt,
  });

  final PairedDevice device;
  final bool connected;
  final bool connecting;
  final DeviceStatus status;
  final DateTime? connectedAt;

  String get deviceId => device.deviceId;

  Map<String, dynamic> toJson() => {
    'device': device.toJson(includePsk: false),
    'connected': connected,
    'connecting': connecting,
    'status': status.toJson(),
    'connectedAt': ?connectedAt?.toUtc().toIso8601String(),
  };
}

/// The facade every UI talks to. Composes identity, sessions, discovery,
/// transfers and gallery, and exposes one event stream.
class PepoEngine {
  PepoEngine(
    this.config, {
    IdentityStore? identityStore,
    DeviceStore? deviceStore,
    TransferStore? transferStore,
    MediaStateStore? mediaStateStore,
    MediaSource? mediaSource,
    List<Discovery>? discovery,
    DeviceStatus Function()? localStatus,
    OfferPolicy? offerPolicy,
    DeletePolicy? deletePolicy,
  }) : _identityStore = identityStore ?? FileIdentityStore(p.join(config.dataDir, 'identity.json')),
       _deviceStore = deviceStore ?? MemoryDeviceStore(),
       _transferStore = transferStore ?? MemoryTransferStore(),
       _mediaStateStore = mediaStateStore ?? MemoryMediaStateStore(),
       // ignore: prefer_initializing_formals
       _mediaSource = mediaSource,
       // ignore: prefer_initializing_formals
       _discovery = discovery,
       // ignore: prefer_initializing_formals
       _localStatus = localStatus,
       // ignore: prefer_initializing_formals
       _offerPolicy = offerPolicy,
       // ignore: prefer_initializing_formals
       _deletePolicy = deletePolicy;

  EngineConfig config;
  final IdentityStore _identityStore;
  final DeviceStore _deviceStore;
  final TransferStore _transferStore;
  final MediaStateStore _mediaStateStore;
  MediaSource? _mediaSource;
  final List<Discovery>? _discovery;
  final DeviceStatus Function()? _localStatus;
  final OfferPolicy? _offerPolicy;
  final DeletePolicy? _deletePolicy;

  late final Identity identity;
  late final SessionManager sessions;
  late final TransferEngine transfers;
  late final GalleryClient gallery;
  MediaServer? mediaServer;
  GuestShareServer? _guest;
  late FolderLayout layout;
  NativeBulk? _native;
  final _events = StreamController<EngineEvent>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, String> _folderNames = {};
  bool _started = false;
  bool _clipboardShare = false;

  Stream<EngineEvent> get events => _events.stream;
  bool get isStarted => _started;
  int get listenPort => sessions.listenPort;

  /// True when the Rust bulk engine loaded (transfers use it whenever the
  /// peer has it too).
  bool get fastLaneAvailable => _native != null;

  /// Port of our fast lane listener, 0 when unavailable.
  int get fastLanePort => _native?.port ?? 0;

  /// Why the fast lane is unavailable, if it is.
  String? get fastLaneError => _native == null ? NativeBulk.lastLoadError : null;
  String get deviceId => identity.deviceId;
  String get shortId => identity.shortId;

  void _emit(EngineEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle

  Future<void> start() async {
    if (_started) return;
    await Directory(config.dataDir).create(recursive: true);
    await Directory(config.downloadRoot).create(recursive: true);
    identity = await _identityStore.loadOrCreate(commonName: 'pepo-${config.deviceName}');
    layout = FolderLayout(root: config.downloadRoot, separateByDevice: config.separateByDevice);
    if (config.fastLane) {
      _native = NativeBulk.tryLoad(libraryPath: config.nativeLibraryPath);
      final port = _native?.listen() ?? 0;
      if (_native != null && port == 0) {
        _log.warning('fast lane: cannot bind a port, will only dial out');
      }
    }
    sessions = SessionManager(
      identity: identity,
      info: LocalDeviceInfo(
        name: config.deviceName,
        platform: config.platform,
        role: config.role,
        appVersion: config.appVersion,
        model: config.model,
      ),
      deviceStore: _deviceStore,
      discovery: _discovery ?? (config.udpDiscovery ? [UdpBeacon()] : const []),
      localStatus: _localStatus,
      preferredPort: config.listenPort,
      native: _native,
    );
    transfers = TransferEngine(
      channels: sessions,
      store: _transferStore,
      destination: _destinationFor,
      policy: _offerPolicy,
      allowExecutables: config.allowExecutables,
    );
    sessions.transfers = transfers;
    gallery = GalleryClient(
      sessions: sessions,
      transfers: transfers,
      stateStore: _mediaStateStore,
      cacheDir: p.join(config.dataDir, 'cache'),
    );
    sessions.handlers.add(gallery);
    sessions.handlers.add(_ClipboardHandler(this));
    final source =
        _mediaSource ??
        (config.mediaRoots.isEmpty
            ? null
            : MediaSourceFs(
                roots: config.mediaRoots,
                cacheDir: p.join(config.dataDir, 'cache', 'own'),
              ));
    if (source != null) {
      _mediaSource = source;
      mediaServer = MediaServer(
        source: source,
        sessions: sessions,
        transfers: transfers,
        deletePolicy: _deletePolicy,
      );
      sessions.handlers.add(mediaServer!);
      await mediaServer!.start();
    }
    _wireEvents();
    for (final d in await _deviceStore.all()) {
      if (d.folderName != null) _folderNames[d.deviceId] = d.folderName!;
    }
    await sessions.start();
    _started = true;
    _log.info('engine started as ${identity.shortId} on port ${sessions.listenPort}');
  }

  void _wireEvents() {
    _subs.add(
      sessions.events.listen((e) {
        switch (e) {
          case DeviceConnectedEvent():
            _emit(DeviceConnectionEvent(deviceId: e.deviceId, connected: true));
            _emit(DevicesChangedEvent());
          case DeviceDisconnectedEvent():
            _emit(DeviceConnectionEvent(deviceId: e.deviceId, connected: false, reason: e.reason));
            _emit(DevicesChangedEvent());
          case DevicePairedEvent():
            unawaited(_ensureFolderName(e.device));
            _emit(DevicePairedEngineEvent(e.device));
            _emit(DevicesChangedEvent());
          case DeviceForgottenEvent():
            _folderNames.remove(e.deviceId);
            _emit(DevicesChangedEvent());
          case DeviceStatusEvent():
            _emit(DeviceStatusChangedEvent(e.deviceId, e.status));
          case DeviceUpdatedEvent():
            _emit(DevicesChangedEvent());
        }
      }),
    );
    _subs.add(
      transfers.rejectedOffers.listen(
        (r) => _emit(
          OfferRejectedEvent(deviceId: r.deviceId, name: r.name, size: r.size, reason: r.reason),
        ),
      ),
    );
    _subs.add(
      transfers.events.listen((e) {
        _emit(TransferChangedEvent(e.record, progressOnly: e.progressOnly, removed: e.removed));
        if (e.record.state == TransferState.done &&
            e.record.direction == TransferDirection.receive) {
          _log.fine('received ${e.record.name} → ${e.record.finalPath}');
        }
      }),
    );
    _subs.add(
      gallery.events.listen((e) {
        _emit(GalleryChangedEvent(e.deviceId, e.change, e.ids));
        if (e.change == GalleryChange.newItem) unawaited(_maybeAutoDownload(e.deviceId, e.ids));
      }),
    );
    _subs.add(sessions.pairing.changes.listen((_) => _emit(PairingChangedEvent(currentInvite))));
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _guest?.dispose();
    _guest = null;
    await gallery.dispose();
    await mediaServer?.stop();
    await transfers.dispose();
    await sessions.dispose();
    _native?.dispose();
    _native = null;
    await _events.close();
  }

  // ---------------------------------------------------------------------------
  // Devices

  Future<List<DeviceView>> devices() async {
    final stored = await _deviceStore.all();
    stored.sort((a, b) => (b.lastSeen ?? b.pairedAt).compareTo(a.lastSeen ?? a.pairedAt));
    return [
      for (final d in stored)
        DeviceView(
          device: sessions.session(d.deviceId)?.device ?? d,
          connected: sessions.session(d.deviceId)?.isConnected ?? false,
          connecting: sessions.session(d.deviceId)?.state == SessionState.connecting,
          status: sessions.session(d.deviceId)?.status ?? const DeviceStatus(),
          connectedAt: sessions.session(d.deviceId)?.connectedAt,
        ),
    ];
  }

  DeviceView? device(String deviceId) {
    final s = sessions.session(deviceId);
    if (s == null) return null;
    return DeviceView(
      device: s.device,
      connected: s.isConnected,
      connecting: s.state == SessionState.connecting,
      status: s.status,
      connectedAt: s.connectedAt,
    );
  }

  Future<void> forget(String deviceId) => sessions.forget(deviceId);

  Future<void> disconnect(String deviceId) => sessions.disconnect(deviceId);

  void reconnectAll() {
    sessions.kickAll();
    unawaited(sessions.probe());
  }

  /// Persists per-device preferences. The clipboard switch is shared with
  /// the peer: a change is stamped and pushed right away when connected.
  Future<void> updateDevice(
    String deviceId, {
    String? name,
    bool? autoDownload,
    bool? convertHeic,
    bool? shareClipboard,
  }) async {
    final current = sessions.session(deviceId)?.device ?? await _deviceStore.find(deviceId);
    if (current == null) return;
    final clipChanged = shareClipboard != null && shareClipboard != current.shareClipboard;
    await sessions.updateDevice(
      current.copyWith(
        name: name,
        autoDownload: autoDownload,
        convertHeic: convertHeic,
        shareClipboard: shareClipboard,
        shareClipboardAt: clipChanged ? DateTime.now() : null,
      ),
    );
    if (clipChanged) {
      final s = sessions.session(deviceId);
      if (s != null && s.isConnected) s.sendStatus();
    }
  }

  Future<void> _ensureFolderName(PairedDevice device) async {
    if (device.folderName != null) return;
    final existing = (await _deviceStore.all()).map((d) => d.folderName).whereType<String>();
    final name = FolderLayout.folderNameFor(device.name, existing);
    _folderNames[device.deviceId] = name;
    final fresh = sessions.session(device.deviceId)?.device ?? device;
    await sessions.updateDevice(fresh.copyWith(folderName: name));
  }

  Future<String> _destinationFor(String deviceId, FileOffer offer) async {
    var folder = _folderNames[deviceId];
    if (folder == null) {
      final d = await _deviceStore.find(deviceId);
      if (d != null) {
        if (d.folderName == null) await _ensureFolderName(d);
        folder = _folderNames[deviceId] ?? d.folderName;
      }
    }
    return layout.directoryFor(deviceFolder: folder, kind: offer.mediaKind);
  }

  // ---------------------------------------------------------------------------
  // Local settings

  Future<void> setDeviceName(String name) async {
    config = config.copyWith(deviceName: name);
    await sessions.updateInfo(sessions.info.copyWith(name: name));
    _emit(DevicesChangedEvent());
  }

  Future<void> setDownloadRoot(String root) async {
    config = config.copyWith(downloadRoot: root);
    layout = layout.copyWith(root: root);
    await Directory(root).create(recursive: true);
  }

  void setSeparateByDevice(bool value) {
    config = config.copyWith(separateByDevice: value);
    layout = layout.copyWith(separateByDevice: value);
  }

  void setClipboardSharing(bool value) => _clipboardShare = value;
  bool get clipboardSharing => _clipboardShare;

  /// Programs (`.exe`, `.msi`, `.apk`...) are neither sent, accepted from a
  /// paired device nor taken from a guest browser unless this is on. The
  /// other device has its own switch; both have to be on.
  void setAllowExecutables(bool value) {
    config = config.copyWith(allowExecutables: value);
    transfers.allowExecutables = value;
    _guest?.allowExecutables = value;
  }

  bool get allowExecutables => config.allowExecutables;

  /// Local IPv4 addresses (for QR codes and the pairing screen).
  Future<List<String>> localAddresses() => localIPv4Addresses();

  // ---------------------------------------------------------------------------
  // Pairing

  PairingInvite? get currentInvite {
    final s = sessions.pairing.active;
    if (s == null) return null;
    return _inviteFor(s);
  }

  PairingInvite _inviteFor(PairingSession s, {List<String>? addresses}) {
    final addrs = addresses ?? _lastAddresses;
    return PairingInvite(
      mode: s.mode,
      expiresAt: s.expiresAt,
      qrText: s.mode == PairingMode.qr
          ? sessions.pairing
                .payloadFor(
                  s,
                  deviceId: identity.deviceId,
                  fingerprint: identity.fingerprint,
                  name: config.deviceName,
                  addresses: addrs,
                  port: sessions.listenPort,
                )
                .toString()
          : null,
      code: s.code,
      addresses: addrs,
      port: sessions.listenPort,
    );
  }

  List<String> _lastAddresses = const [];

  /// Shows a QR invitation (valid 2 minutes, single use).
  Future<PairingInvite> startQrPairing() async {
    _lastAddresses = await localIPv4Addresses();
    final s = sessions.pairing.startQr();
    unawaited(sessions.probe());
    final invite = _inviteFor(s);
    _emit(PairingChangedEvent(invite));
    return invite;
  }

  /// Shows a 6-digit code invitation (for devices without a camera).
  Future<PairingInvite> startCodePairing() async {
    _lastAddresses = await localIPv4Addresses();
    final s = sessions.pairing.startManualCode(identity.deviceId);
    final invite = _inviteFor(s);
    _emit(PairingChangedEvent(invite));
    return invite;
  }

  void cancelPairing() => sessions.pairing.cancel();

  /// Pairs using scanned/pasted QR text. Returns the new device.
  Future<PairedDevice> pairWithQrText(String text) async {
    final payload = QrPayload.tryParse(text);
    if (payload == null) {
      throw HandshakeException('not a PepoConnect code', code: ErrorCode.badRequest);
    }
    final device = await sessions.pairWithQr(payload);
    await _ensureFolderName(device);
    return device;
  }

  /// Pairs by code with a host chosen from discovery or typed as host:port.
  Future<PairedDevice> pairWithCode({
    required String code,
    PeerCandidate? candidate,
    String? host,
    int? port,
  }) async {
    String hostDeviceId;
    String hostFingerprint;
    List<String> addresses;
    int targetPort;
    if (candidate != null && candidate.shortFingerprint.isNotEmpty) {
      final ident = await sessions.identify(candidate.addresses.first, candidate.port);
      if (!ident.fingerprint.startsWith(candidate.shortFingerprint)) {
        throw HandshakeException('device identity changed');
      }
      hostDeviceId = ident.deviceId;
      hostFingerprint = ident.fingerprint;
      addresses = candidate.addresses;
      targetPort = candidate.port;
    } else {
      if (host == null) throw ArgumentError('host or candidate required');
      targetPort = port ?? config.listenPort;
      final ident = await sessions.identify(host, targetPort);
      hostDeviceId = ident.deviceId;
      hostFingerprint = ident.fingerprint;
      addresses = [host];
    }
    final device = await sessions.pairWithCode(
      code: code,
      addresses: addresses,
      port: targetPort,
      hostDeviceId: hostDeviceId,
      hostFingerprint: hostFingerprint,
    );
    await _ensureFolderName(device);
    return device;
  }

  /// Devices seen on the network that are not paired yet.
  List<PeerCandidate> discoveredCandidates() {
    final paired = sessions.sessions.map((s) => s.deviceId).toSet();
    return sessions.candidates.where((c) => !paired.contains(c.deviceId)).toList();
  }

  // ---------------------------------------------------------------------------
  // Transfers

  Future<List<TransferRecord>> sendFiles(String deviceId, List<String> paths) async {
    final out = <TransferRecord>[];
    for (final path in paths) {
      out.add(await transfers.send(deviceId: deviceId, path: path));
    }
    return out;
  }

  Future<void> cancelTransfer(int id, {bool pause = false}) =>
      transfers.cancel(id, reason: pause ? CancelReason.pause : CancelReason.abort);

  /// Resumes a paused transfer. Outgoing ones are re-queued under the same id;
  /// a paused download of a gallery item is requested from the device again.
  /// Returns false when there is nothing to resume from this side.
  Future<bool> resumeTransfer(int id) async {
    if (await transfers.resume(id) != null) return true;
    final r = (await transfers.store.all()).where((r) => r.id == id).firstOrNull;
    if (r == null ||
        r.direction != TransferDirection.receive ||
        r.state != TransferState.paused ||
        r.sourceId == null) {
      return false;
    }
    await downloadItems(r.deviceId, [r.sourceId!]);
    return true;
  }

  List<TransferRecord> get activeTransfers => transfers.transfers;

  // ---------------------------------------------------------------------------
  // Gallery (hub side)

  Future<void> refreshGallery(String deviceId, {Set<MediaKind>? kinds}) =>
      gallery.refresh(deviceId, kinds: kinds);

  Future<bool> loadMoreGallery(String deviceId) => gallery.loadMore(deviceId);

  Future<Uint8List?> thumbnail(String deviceId, String id) => gallery.thumbnail(deviceId, id);

  Future<Uint8List?> preview(String deviceId, String id) => gallery.preview(deviceId, id);

  Future<void> downloadItems(String deviceId, List<String> ids) async {
    final device = sessions.session(deviceId)?.device;
    for (final id in ids) {
      await gallery.download(deviceId, id, convertHeic: device?.convertHeic ?? false);
    }
  }

  Future<List<String>> deleteOnDevice(String deviceId, List<String> ids) =>
      gallery.deleteOnDevice(deviceId, ids);

  Future<void> dismissItem(String deviceId, String id) => gallery.dismiss(deviceId, id);

  /// The gallery left the screen with [ids] on it: they stop being new.
  Future<void> markGallerySeen(String deviceId, Iterable<String> ids) =>
      gallery.markSeen(deviceId, ids);

  Future<void> _maybeAutoDownload(String deviceId, List<String> ids) async {
    final device = sessions.session(deviceId)?.device;
    if (device == null || !device.autoDownload) return;
    try {
      await downloadItems(deviceId, ids);
    } catch (e) {
      _log.fine('auto download failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Clipboard (text)

  /// Sends [text] to every connected device with clipboard sharing enabled
  /// (or to [deviceId] only). Returns the names of the devices it went to;
  /// empty when nobody was connected to receive it.
  List<String> sendClipboard(String text, {String? deviceId}) {
    if (text.isEmpty || text.length > 64 * 1024) return const [];
    final sent = <String>[];
    for (final s in sessions.sessions) {
      if (!s.isConnected) continue;
      if (deviceId != null && s.deviceId != deviceId) continue;
      if (deviceId == null && !s.device.shareClipboard) continue;
      final control = s.control;
      if (control == null) continue;
      control.send(MsgType.clipboardSet, data: {'mime': 'text/plain', 'text': text});
      sent.add(s.device.name);
    }
    return sent;
  }

  /// Connected devices that receive our clipboard.
  List<String> clipboardTargets() => [
    for (final s in sessions.sessions)
      if (s.isConnected && s.device.shareClipboard) s.device.name,
  ];

  // ---------------------------------------------------------------------------
  // Guest share (browser, no app)

  GuestShareServer _guestServer() {
    var g = _guest;
    if (g == null) {
      g = GuestShareServer(hostName: config.deviceName, receiveDir: layout.guestsDirectory());
      _guest = g;
      _subs.add(
        g.events.listen(
          (e) => _emit(
            GuestShareChangedEvent(
              kind: e.kind.name,
              session: e.session.toJson(),
              fileName: e.fileName,
              bytes: e.bytes,
              remote: e.remote,
              path: e.path,
            ),
          ),
        ),
      );
    }
    g.receiveDir = layout.guestsDirectory();
    g.allowExecutables = config.allowExecutables;
    return g;
  }

  /// Current guest session (null when none or expired).
  GuestSession? get guestSession => _guest?.session;

  /// Includes accepted browser transfers whose invitation has since expired.
  int get activeGuestTransfers => _guest?.activeTransfers ?? 0;

  /// Port of the guest HTTP server (0 until first use).
  int get guestPort => _guest?.boundPort ?? 0;

  /// One-time link to let a guest download [paths]. Returns the URLs for
  /// every local address.
  Future<List<String>> startGuestSend(List<String> paths, {String? message}) async {
    final g = _guestServer();
    final s = await g.startSend(paths, message: message);
    return s.urls(await localIPv4Addresses(), g.boundPort);
  }

  /// One-time link to let a guest upload files into the guests folder.
  Future<List<String>> startGuestReceive({String? message}) async {
    final g = _guestServer();
    final s = await g.startReceive(message: message);
    return s.urls(await localIPv4Addresses(), g.boundPort);
  }

  void cancelGuestShare() => _guest?.cancel();

  // ---------------------------------------------------------------------------
  // Own gallery (phone side helpers)

  /// The media source published by this device, if any.
  MediaSource? get ownMediaSource => _mediaSource;

  /// Enables/disables automatic sending of new photos to [deviceId].
  void setAutoSend(String deviceId, bool enabled) {
    final server = mediaServer;
    if (server == null) return;
    final set = server.autoSendTo ?? <String>{};
    if (enabled) {
      set.add(deviceId);
    } else {
      set.remove(deviceId);
    }
    server.autoSendTo = set;
  }
}

class _ClipboardHandler implements MessageHandler {
  _ClipboardHandler(this.engine);
  final PepoEngine engine;

  @override
  Future<bool> handleMessage(String deviceId, PeerConnection conn, ControlMessage m) async {
    if (m.type != MsgType.clipboardSet) return false;
    final text = m.optStr('text');
    if (text != null && text.isNotEmpty) {
      engine._emit(ClipboardReceivedEvent(deviceId, text));
    }
    return true;
  }
}
