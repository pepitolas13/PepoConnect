import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../net/frame.dart';
import '../net/peer_connection.dart';
import '../net/session.dart';
import '../protocol/message_types.dart';
import '../protocol/models.dart';
import '../transfer/transfer_engine.dart';
import '../util/bytes.dart';
import 'media_source.dart';

final _log = Logger('pepo.media.server');

/// Decides whether a remote hub may delete items (Android shows a system
/// dialog; desktops may ask the user).
typedef DeletePolicy = Future<bool> Function(String deviceId, List<String> ids);

/// Serves this device's gallery to connected hubs and pushes `media.new`
/// events with an inline thumbnail as soon as a photo appears.
class MediaServer implements MessageHandler {
  MediaServer({
    required this.source,
    required this.sessions,
    required this.transfers,
    DeletePolicy? deletePolicy,
    this.thumbPx = 320,
    this.maxThumbBatch = 32,
    this.autoSendTo,
  }) : deletePolicy = deletePolicy ?? ((_, _) async => true);

  final MediaSource source;
  final SessionManager sessions;
  final TransferEngine transfers;
  final DeletePolicy deletePolicy;
  final int thumbPx;
  final int maxThumbBatch;

  /// Device ids that get every new photo sent automatically (phone-side
  /// "auto send" setting). Null = none.
  Set<String>? autoSendTo;

  StreamSubscription<MediaChange>? _sub;

  Future<void> start() async {
    await source.start();
    _sub = source.changes.listen(_onChange);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await source.stop();
  }

  Future<void> _onChange(MediaChange change) async {
    if (change.removed.isNotEmpty) {
      for (final s in sessions.sessions) {
        if (s.isConnected) {
          s.control?.send(MsgType.mediaRemoved, data: {'ids': change.removed});
        }
      }
    }
    for (final item in change.added) {
      Uint8List? thumb;
      try {
        thumb = await source.thumbnail(item.id, maxPx: thumbPx);
      } catch (e) {
        _log.fine('thumbnail for ${item.id} failed: $e');
      }
      for (final s in sessions.sessions) {
        if (!s.isConnected) continue;
        s.control?.send(MsgType.mediaNew, data: {'item': item.toJson()}, body: thumb);
        final auto = autoSendTo;
        if (auto != null && auto.contains(s.deviceId)) {
          unawaited(_sendOriginal(s.deviceId, item.id, convert: false));
        }
      }
    }
  }

  @override
  Future<bool> handleMessage(String deviceId, PeerConnection conn, ControlMessage m) async {
    switch (m.type) {
      case MsgType.mediaIndex:
        final kinds = m.list<String>('kinds').map(MediaKind.fromCode).toSet();
        final since = m.optInt('since');
        final page = await source.index(
          page: m.optInt('page') ?? 0,
          pageSize: (m.optInt('pageSize') ?? 200).clamp(1, 500),
          kinds: kinds.isEmpty ? null : kinds,
          since: since == null ? null : DateTime.fromMillisecondsSinceEpoch(since, isUtc: true),
        );
        conn.respond(m.reqId, MsgType.mediaIndexResult, data: page.toJson());
        return true;
      case MsgType.mediaThumb:
        final ids = m.list<String>('ids').take(maxThumbBatch).toList();
        final px = (m.optInt('px') ?? thumbPx).clamp(64, 1024);
        final parts = <Map<String, dynamic>>[];
        final body = BytesBuilder(copy: false);
        for (final id in ids) {
          Uint8List? t;
          try {
            t = await source.thumbnail(id, maxPx: px);
          } catch (_) {}
          parts.add({'id': id, 'len': t?.length ?? 0});
          if (t != null) body.add(t);
        }
        conn.respond(
          m.reqId,
          MsgType.mediaThumbBatch,
          data: {'parts': parts},
          body: body.takeBytes(),
        );
        return true;
      case MsgType.mediaPreview:
        final id = m.str('id');
        final px = (m.optInt('maxPx') ?? 1600).clamp(320, 4096);
        final bytes = await source.preview(id, maxPx: px);
        if (bytes == null) {
          conn.respondError(m.reqId, ErrorCode.notFound, 'no preview for $id');
        } else {
          conn.respond(
            m.reqId,
            MsgType.mediaPreviewResult,
            data: {'id': id, 'mime': 'image/jpeg'},
            body: bytes,
          );
        }
        return true;
      case MsgType.fileRequest:
        final id = m.str('id');
        final convert = m.optStr('convert') == 'jpeg';
        final ok = await _sendOriginal(deviceId, id, convert: convert);
        if (ok) {
          conn.respond(m.reqId, MsgType.fileAccept, data: {'id': id});
        } else {
          conn.respondError(m.reqId, ErrorCode.notFound, 'item $id not available');
        }
        return true;
      case MsgType.mediaDelete:
        final ids = m.list<String>('ids');
        var deleted = <String>[];
        if (ids.isNotEmpty && await deletePolicy(deviceId, ids)) {
          deleted = await source.delete(ids);
        }
        conn.respond(m.reqId, MsgType.mediaDeleteResult, data: {'deleted': deleted});
        return true;
      default:
        return false;
    }
  }

  Future<bool> _sendOriginal(String deviceId, String id, {required bool convert}) async {
    final item = await source.item(id);
    final path = await source.originalPath(id);
    if (item == null || path == null) return false;
    var sendPath = path;
    var name = item.name;
    if (convert && _isHeic(item)) {
      final converted = await convertHeicToJpeg(path);
      if (converted != null) {
        sendPath = converted;
        name = '${_stripExtension(name)}.jpg';
      }
    }
    try {
      await transfers.send(
        deviceId: deviceId,
        path: sendPath,
        name: name,
        mime: sendPath == path ? item.mime : 'image/jpeg',
        mediaKind: item.kind,
        sourceId: id,
      );
      return true;
    } catch (e) {
      _log.warning('cannot send $id: $e');
      return false;
    }
  }

  /// HEIC → JPEG conversion hook (platform layer sets it: native on Android/
  /// iOS). Returns the path of the converted file or null.
  Future<String?> Function(String path) convertHeicToJpeg = (_) async => null;

  static bool _isHeic(MediaItem item) =>
      item.mime == 'image/heic' ||
      item.mime == 'image/heif' ||
      item.name.toLowerCase().endsWith('.heic') ||
      item.name.toLowerCase().endsWith('.heif');

  static String _stripExtension(String name) {
    final i = name.lastIndexOf('.');
    return i <= 0 ? name : name.substring(0, i);
  }

  /// Parses a `media.thumb.batch` response into id → bytes.
  static Map<String, Uint8List> parseThumbBatch(ControlMessage m) {
    final out = <String, Uint8List>{};
    var offset = 0;
    for (final part in m.list<Map<String, dynamic>>('parts')) {
      final len = part['len'] as int;
      final id = part['id'] as String;
      if (len > 0 && offset + len <= m.body.length) {
        out[id] = Uint8List.sublistView(m.body, offset, offset + len);
      }
      offset += len;
    }
    return out;
  }
}

/// Small helper so callers do not need `dart:typed_data` for empty bodies.
final Uint8List emptyBody = Uint8List(0);

// Keep bytes helper imported for future use (base64 in thumbnails metadata).
// ignore: unused_element
final _unused = base64Url;
