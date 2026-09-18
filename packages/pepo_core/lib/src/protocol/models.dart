import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../util/bytes.dart';

/// Operating system family of a device, as sent on the wire.
enum DevicePlatform {
  windows('win'),
  linux('lin'),
  android('and'),
  ios('ios'),
  macos('mac'),
  unknown('unk');

  const DevicePlatform(this.code);
  final String code;

  static DevicePlatform fromCode(String? code) =>
      DevicePlatform.values.firstWhere((p) => p.code == code, orElse: () => DevicePlatform.unknown);

  bool get isMobile => this == android || this == ios;
}

/// What a device does in the pairing: hubs receive galleries, phones publish
/// them, `both` for desktop↔desktop.
enum DeviceRole {
  hub('hub'),
  phone('phone'),
  both('both');

  const DeviceRole(this.code);
  final String code;

  static DeviceRole fromCode(String? code) =>
      DeviceRole.values.firstWhere((r) => r.code == code, orElse: () => DeviceRole.both);
}

/// Static description of the local device, sent in `hello`.
@immutable
class LocalDeviceInfo {
  const LocalDeviceInfo({
    required this.name,
    required this.platform,
    required this.role,
    required this.appVersion,
    this.model,
  });

  final String name;
  final DevicePlatform platform;
  final DeviceRole role;
  final String appVersion;
  final String? model;

  LocalDeviceInfo copyWith({String? name, DeviceRole? role}) => LocalDeviceInfo(
    name: name ?? this.name,
    platform: platform,
    role: role ?? this.role,
    appVersion: appVersion,
    model: model,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'platform': platform.code,
    'role': role.code,
    'app': appVersion,
    if (model != null) 'model': model,
  };
}

/// Live status of a remote device (`device.info` event).
@immutable
class DeviceStatus {
  const DeviceStatus({
    this.battery,
    this.charging,
    this.storageFree,
    this.storageTotal,
    this.addresses = const [],
    this.listenPort,
    this.bulkPort,
  });

  final int? battery;
  final bool? charging;
  final int? storageFree;
  final int? storageTotal;
  final List<String> addresses;
  final int? listenPort;

  /// Port of the peer's fast lane listener (Rust bulk engine), if it has one.
  final int? bulkPort;

  Map<String, dynamic> toJson() => {
    if (battery != null) 'battery': battery,
    if (charging != null) 'charging': charging,
    if (storageFree != null) 'storageFree': storageFree,
    if (storageTotal != null) 'storageTotal': storageTotal,
    'ips': addresses,
    if (listenPort != null) 'port': listenPort,
    if (bulkPort != null && bulkPort! > 0) 'fast': bulkPort,
  };

  factory DeviceStatus.fromJson(Map<String, dynamic> json) => DeviceStatus(
    battery: json['battery'] as int?,
    charging: json['charging'] as bool?,
    storageFree: json['storageFree'] as int?,
    storageTotal: json['storageTotal'] as int?,
    addresses: (json['ips'] as List<dynamic>? ?? const []).cast<String>(),
    listenPort: json['port'] as int?,
    bulkPort: json['fast'] as int?,
  );
}

/// A device we have paired with. Persisted by the platform store; the PSK is
/// kept in secure storage where available.
@immutable
class PairedDevice {
  const PairedDevice({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.role,
    required this.fingerprint,
    required this.psk,
    required this.weInitiate,
    required this.pairedAt,
    this.model,
    this.lastAddresses = const [],
    this.lastPort,
    this.lastSeen,
    this.folderName,
    this.autoDownload = false,
    this.convertHeic = false,
    this.shareClipboard = false,
    this.shareClipboardAt,
  });

  final String deviceId;
  final String name;
  final DevicePlatform platform;
  final DeviceRole role;

  /// SHA-256 hex of the peer certificate (pinned).
  final String fingerprint;

  /// 32-byte pre-shared key derived at pairing.
  final Uint8List psk;

  /// True when this device is the one that dials (scanned the QR / typed
  /// the code). The other side listens.
  final bool weInitiate;
  final DateTime pairedAt;
  final String? model;
  final List<String> lastAddresses;
  final int? lastPort;
  final DateTime? lastSeen;

  /// Folder name used under the download root when separating per device.
  final String? folderName;
  final bool autoDownload;
  final bool convertHeic;

  /// Clipboard sharing with this device. One switch for both directions: it
  /// is mirrored to the peer (`device.info`) and the newer [shareClipboardAt]
  /// wins when the two sides disagree.
  final bool shareClipboard;

  /// When [shareClipboard] was last changed (by either side). Null on
  /// records written before the flag was synchronised.
  final DateTime? shareClipboardAt;

  String get shortId => 'PEPO-${deviceId.substring(0, 4)}-${deviceId.substring(4, 8)}';

  PairedDevice copyWith({
    String? name,
    DevicePlatform? platform,
    DeviceRole? role,
    String? model,
    List<String>? lastAddresses,
    int? lastPort,
    DateTime? lastSeen,
    String? folderName,
    bool? autoDownload,
    bool? convertHeic,
    bool? shareClipboard,
    DateTime? shareClipboardAt,
    bool? weInitiate,
  }) => PairedDevice(
    deviceId: deviceId,
    name: name ?? this.name,
    platform: platform ?? this.platform,
    role: role ?? this.role,
    fingerprint: fingerprint,
    psk: psk,
    weInitiate: weInitiate ?? this.weInitiate,
    pairedAt: pairedAt,
    model: model ?? this.model,
    lastAddresses: lastAddresses ?? this.lastAddresses,
    lastPort: lastPort ?? this.lastPort,
    lastSeen: lastSeen ?? this.lastSeen,
    folderName: folderName ?? this.folderName,
    autoDownload: autoDownload ?? this.autoDownload,
    convertHeic: convertHeic ?? this.convertHeic,
    shareClipboard: shareClipboard ?? this.shareClipboard,
    shareClipboardAt: shareClipboardAt ?? this.shareClipboardAt,
  );

  Map<String, dynamic> toJson({bool includePsk = true}) => {
    'deviceId': deviceId,
    'name': name,
    'platform': platform.code,
    'role': role.code,
    'fingerprint': fingerprint,
    if (includePsk) 'psk': base64Url(psk),
    'weInitiate': weInitiate,
    'pairedAt': pairedAt.toUtc().toIso8601String(),
    if (model != null) 'model': model,
    'lastAddresses': lastAddresses,
    if (lastPort != null) 'lastPort': lastPort,
    if (lastSeen != null) 'lastSeen': lastSeen!.toUtc().toIso8601String(),
    if (folderName != null) 'folderName': folderName,
    'autoDownload': autoDownload,
    'convertHeic': convertHeic,
    'shareClipboard': shareClipboard,
    if (shareClipboardAt != null) 'shareClipboardAt': shareClipboardAt!.millisecondsSinceEpoch,
  };

  factory PairedDevice.fromJson(Map<String, dynamic> json, {Uint8List? psk}) => PairedDevice(
    deviceId: json['deviceId'] as String,
    name: json['name'] as String,
    platform: DevicePlatform.fromCode(json['platform'] as String?),
    role: DeviceRole.fromCode(json['role'] as String?),
    fingerprint: json['fingerprint'] as String,
    psk: psk ?? base64UrlDecode(json['psk'] as String),
    weInitiate: json['weInitiate'] as bool? ?? true,
    pairedAt: DateTime.parse(json['pairedAt'] as String),
    model: json['model'] as String?,
    lastAddresses: (json['lastAddresses'] as List<dynamic>? ?? const []).cast<String>(),
    lastPort: json['lastPort'] as int?,
    lastSeen: json['lastSeen'] == null ? null : DateTime.parse(json['lastSeen'] as String),
    folderName: json['folderName'] as String?,
    autoDownload: json['autoDownload'] as bool? ?? false,
    convertHeic: json['convertHeic'] as bool? ?? false,
    shareClipboard: json['shareClipboard'] as bool? ?? false,
    shareClipboardAt: json['shareClipboardAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json['shareClipboardAt'] as int),
  );
}

/// Kind of a gallery item.
enum MediaKind {
  image('image'),
  video('video');

  const MediaKind(this.code);
  final String code;

  static MediaKind fromCode(String? code) => code == 'video' ? MediaKind.video : MediaKind.image;
}

/// A photo or video as described by the source device.
@immutable
class MediaItem {
  const MediaItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.width,
    required this.height,
    required this.takenAt,
    this.durationMs,
    this.size,
    this.mime,
    this.album,
  });

  /// Opaque id on the source device (MediaStore id, PHAsset local id, path).
  final String id;
  final MediaKind kind;
  final String name;
  final int width;
  final int height;
  final DateTime takenAt;
  final int? durationMs;
  final int? size;
  final String? mime;
  final String? album;

  bool get isVideo => kind == MediaKind.video;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.code,
    'name': name,
    'w': width,
    'h': height,
    'takenAt': takenAt.toUtc().millisecondsSinceEpoch,
    if (durationMs != null) 'dur': durationMs,
    if (size != null) 'size': size,
    if (mime != null) 'mime': mime,
    if (album != null) 'album': album,
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    id: json['id'] as String,
    kind: MediaKind.fromCode(json['kind'] as String?),
    name: json['name'] as String,
    width: json['w'] as int? ?? 0,
    height: json['h'] as int? ?? 0,
    takenAt: DateTime.fromMillisecondsSinceEpoch(json['takenAt'] as int, isUtc: true),
    durationMs: json['dur'] as int?,
    size: json['size'] as int?,
    mime: json['mime'] as String?,
    album: json['album'] as String?,
  );
}

/// A page of the media index.
@immutable
class MediaPage {
  const MediaPage({
    required this.items,
    required this.total,
    required this.nextPage,
    required this.indexVersion,
  });

  final List<MediaItem> items;
  final int total;
  final int? nextPage;
  final int indexVersion;

  Map<String, dynamic> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
    'total': total,
    if (nextPage != null) 'nextPage': nextPage,
    'indexVersion': indexVersion,
  };

  factory MediaPage.fromJson(Map<String, dynamic> json) => MediaPage(
    items: (json['items'] as List<dynamic>)
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    total: json['total'] as int,
    nextPage: json['nextPage'] as int?,
    indexVersion: json['indexVersion'] as int? ?? 0,
  );
}

/// Direction of a transfer from the local point of view.
enum TransferDirection { send, receive }

/// Offer of a file to the receiving side (`file.offer`).
@immutable
class FileOffer {
  const FileOffer({
    required this.transferId,
    required this.name,
    required this.size,
    required this.mime,
    this.modifiedAt,
    this.mediaKind,
    this.sourceId,
    this.resumable = true,
    this.fast = false,
  });

  final int transferId;
  final String name;
  final int size;
  final String mime;
  final DateTime? modifiedAt;
  final MediaKind? mediaKind;

  /// Set when the file is a gallery item (lets the hub link it).
  final String? sourceId;
  final bool resumable;

  /// The sender can move this file on the fast lane (Rust engine); the
  /// receiver answers `fast: true` in `file.accept` when it can too.
  final bool fast;

  Map<String, dynamic> toJson() => {
    'x': transferId,
    'name': name,
    'size': size,
    'mime': mime,
    if (modifiedAt != null) 'mtime': modifiedAt!.toUtc().millisecondsSinceEpoch,
    if (mediaKind != null) 'kind': mediaKind!.code,
    if (sourceId != null) 'sourceId': sourceId,
    'resumable': resumable,
    if (fast) 'fast': true,
  };

  factory FileOffer.fromJson(Map<String, dynamic> json) => FileOffer(
    transferId: json['x'] as int,
    name: json['name'] as String,
    size: json['size'] as int,
    mime: json['mime'] as String? ?? 'application/octet-stream',
    modifiedAt: json['mtime'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json['mtime'] as int, isUtc: true),
    mediaKind: json['kind'] == null ? null : MediaKind.fromCode(json['kind'] as String),
    sourceId: json['sourceId'] as String?,
    resumable: json['resumable'] as bool? ?? true,
    fast: json['fast'] as bool? ?? false,
  );
}
