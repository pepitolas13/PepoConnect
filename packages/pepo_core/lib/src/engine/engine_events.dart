import '../media/gallery_client.dart';
import '../pairing/pairing_session.dart';
import '../protocol/models.dart';
import '../transfer/transfer_record.dart';

/// Everything the UI can observe. Each event is serializable so the engine
/// may run in another isolate.
sealed class EngineEvent {
  const EngineEvent();

  Map<String, dynamic> toJson();

  static EngineEvent fromJson(Map<String, dynamic> j) {
    switch (j['e'] as String) {
      case 'devices':
        return DevicesChangedEvent();
      case 'connection':
        return DeviceConnectionEvent(
          deviceId: j['deviceId'] as String,
          connected: j['connected'] as bool,
          reason: j['reason'] as String?,
        );
      case 'status':
        return DeviceStatusChangedEvent(
          j['deviceId'] as String,
          DeviceStatus.fromJson(j['status'] as Map<String, dynamic>),
        );
      case 'paired':
        return DevicePairedEngineEvent(PairedDevice.fromJson(j['device'] as Map<String, dynamic>));
      case 'pairing':
        return PairingChangedEvent(
          j['invite'] == null ? null : PairingInvite.fromJson(j['invite'] as Map<String, dynamic>),
        );
      case 'transfer':
        return TransferChangedEvent(
          TransferRecord.fromJson(j['record'] as Map<String, dynamic>),
          progressOnly: j['progressOnly'] as bool? ?? false,
          removed: j['removed'] as bool? ?? false,
        );
      case 'gallery':
        return GalleryChangedEvent(
          j['deviceId'] as String,
          GalleryChange.values.byName(j['change'] as String),
          (j['ids'] as List<dynamic>? ?? const []).cast<String>(),
        );
      case 'clipboard':
        return ClipboardReceivedEvent(j['deviceId'] as String, j['text'] as String);
      case 'guest':
        return GuestShareChangedEvent(
          kind: j['kind'] as String,
          session: j['session'] as Map<String, dynamic>?,
          fileName: j['fileName'] as String?,
          bytes: j['bytes'] as int?,
          remote: j['remote'] as String?,
          path: j['path'] as String?,
        );
      case 'log':
        return EngineLogEvent(j['level'] as String, j['message'] as String);
      default:
        throw FormatException('unknown engine event ${j['e']}');
    }
  }
}

/// The device list (or a device's settings) changed; re-read [PepoEngine.devices].
class DevicesChangedEvent extends EngineEvent {
  @override
  Map<String, dynamic> toJson() => {'e': 'devices'};
}

class DeviceConnectionEvent extends EngineEvent {
  const DeviceConnectionEvent({required this.deviceId, required this.connected, this.reason});
  final String deviceId;
  final bool connected;
  final String? reason;

  @override
  Map<String, dynamic> toJson() => {
    'e': 'connection',
    'deviceId': deviceId,
    'connected': connected,
    'reason': ?reason,
  };
}

class DeviceStatusChangedEvent extends EngineEvent {
  const DeviceStatusChangedEvent(this.deviceId, this.status);
  final String deviceId;
  final DeviceStatus status;

  @override
  Map<String, dynamic> toJson() => {'e': 'status', 'deviceId': deviceId, 'status': status.toJson()};
}

class DevicePairedEngineEvent extends EngineEvent {
  const DevicePairedEngineEvent(this.device);
  final PairedDevice device;

  @override
  Map<String, dynamic> toJson() => {'e': 'paired', 'device': device.toJson(includePsk: false)};
}

/// The active pairing invitation shown by this device (QR or code), or null.
class PairingInvite {
  const PairingInvite({
    required this.mode,
    required this.expiresAt,
    this.qrText,
    this.code,
    this.addresses = const [],
    this.port = 0,
  });

  final PairingMode mode;
  final DateTime expiresAt;
  final String? qrText;
  final String? code;
  final List<String> addresses;
  final int port;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'qrText': ?qrText,
    'code': ?code,
    'addresses': addresses,
    'port': port,
  };

  factory PairingInvite.fromJson(Map<String, dynamic> j) => PairingInvite(
    mode: PairingMode.values.byName(j['mode'] as String),
    expiresAt: DateTime.parse(j['expiresAt'] as String),
    qrText: j['qrText'] as String?,
    code: j['code'] as String?,
    addresses: (j['addresses'] as List<dynamic>? ?? const []).cast<String>(),
    port: j['port'] as int? ?? 0,
  );
}

class PairingChangedEvent extends EngineEvent {
  const PairingChangedEvent(this.invite);
  final PairingInvite? invite;

  @override
  Map<String, dynamic> toJson() => {'e': 'pairing', 'invite': invite?.toJson()};
}

class TransferChangedEvent extends EngineEvent {
  const TransferChangedEvent(this.record, {this.progressOnly = false, this.removed = false});
  final TransferRecord record;
  final bool progressOnly;

  /// The record was dropped (superseded by a resumption under another id).
  final bool removed;

  @override
  Map<String, dynamic> toJson() => {
    'e': 'transfer',
    'record': record.toJson(),
    'progressOnly': progressOnly,
    'removed': removed,
  };
}

class GalleryChangedEvent extends EngineEvent {
  const GalleryChangedEvent(this.deviceId, this.change, this.ids);
  final String deviceId;
  final GalleryChange change;
  final List<String> ids;

  @override
  Map<String, dynamic> toJson() => {
    'e': 'gallery',
    'deviceId': deviceId,
    'change': change.name,
    'ids': ids,
  };
}

class ClipboardReceivedEvent extends EngineEvent {
  const ClipboardReceivedEvent(this.deviceId, this.text);
  final String deviceId;
  final String text;

  @override
  Map<String, dynamic> toJson() => {'e': 'clipboard', 'deviceId': deviceId, 'text': text};
}

/// Guest (browser) share session changed: created, opened, downloaded,
/// uploaded, uploadFailed, expired, cancelled.
class GuestShareChangedEvent extends EngineEvent {
  const GuestShareChangedEvent({
    required this.kind,
    this.session,
    this.fileName,
    this.bytes,
    this.remote,
    this.path,
  });
  final String kind;
  final Map<String, dynamic>? session;
  final String? fileName;
  final int? bytes;
  final String? remote;
  final String? path;

  @override
  Map<String, dynamic> toJson() => {
    'e': 'guest',
    'kind': kind,
    'session': ?session,
    'fileName': ?fileName,
    'bytes': ?bytes,
    'remote': ?remote,
    'path': ?path,
  };
}

class EngineLogEvent extends EngineEvent {
  const EngineLogEvent(this.level, this.message);
  final String level;
  final String message;

  @override
  Map<String, dynamic> toJson() => {'e': 'log', 'level': level, 'message': message};
}
