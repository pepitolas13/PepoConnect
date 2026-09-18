import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../transfer/name_sanitizer.dart';
import '../util/bytes.dart';
import 'guest_share_page.dart';

final _log = Logger('pepo.share');

/// Direction of a guest session.
enum GuestMode { send, receive }

/// A file offered to guests.
class GuestFile {
  GuestFile({required this.id, required this.path, required this.name, required this.size});
  final String id;
  final String path;
  final String name;
  final int size;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'size': size};
}

/// What happened in a guest session.
enum GuestEventKind { created, opened, downloaded, uploaded, uploadFailed, expired, cancelled }

class GuestShareEvent {
  GuestShareEvent(this.session, this.kind, {this.fileName, this.bytes, this.remote, this.path});
  final GuestSession session;
  final GuestEventKind kind;
  final String? fileName;
  final int? bytes;
  final String? remote;
  final String? path;
}

/// One-time link shown as QR/URL to a guest.
class GuestSession {
  GuestSession({
    required this.token,
    required this.mode,
    required this.expiresAt,
    required this.files,
    this.message,
  });

  final String token;
  final GuestMode mode;
  final DateTime expiresAt;
  final List<GuestFile> files;
  final String? message;
  String? boundRemote;
  int downloads = 0;
  int uploads = 0;
  bool cancelled = false;

  bool get isExpired => cancelled || DateTime.now().isAfter(expiresAt);
  Duration get remaining => expiresAt.difference(DateTime.now());
  int get totalBytes => files.fold(0, (a, f) => a + f.size);

  /// URLs for every local address.
  List<String> urls(List<String> addresses, int port) =>
      [for (final a in addresses) 'http://$a:$port/s/$token'];

  Map<String, dynamic> toJson() => {
        'token': token,
        'mode': mode.name,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'files': files.map((f) => f.toJson()).toList(),
        'message': ?message,
        'boundRemote': ?boundRemote,
        'downloads': downloads,
        'uploads': uploads,
        'cancelled': cancelled,
      };
}

/// Plain-HTTP LAN server for "share with anyone" (guests without the app).
///
/// Security model: 32-byte single-use token in the URL, bound to the first
/// client that opens it, 10-minute expiry, uploads size-capped and
/// sanitized. Transport is unencrypted on purpose: browsers would refuse a
/// self-signed certificate.
class GuestShareServer {
  GuestShareServer({
    required this.hostName,
    required this.receiveDir,
    this.port = 47475,
    this.ttl = const Duration(minutes: 10),
    this.maxUploadBytes = 8 * 1024 * 1024 * 1024,
  });

  final String hostName;
  String receiveDir;
  final int port;
  final Duration ttl;
  final int maxUploadBytes;

  HttpServer? _server;
  GuestSession? _session;
  final _events = StreamController<GuestShareEvent>.broadcast();
  Timer? _expiry;

  Stream<GuestShareEvent> get events => _events.stream;
  GuestSession? get session => _session?.isExpired == true ? null : _session;
  int get boundPort => _server?.port ?? port;
  bool get isRunning => _server != null;

  Future<void> _ensureServer() async {
    if (_server != null) return;
    HttpServer? server;
    for (var pp = port; pp < port + 10; pp++) {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv6, pp, v6Only: false);
        break;
      } on SocketException {
        try {
          server = await HttpServer.bind(InternetAddress.anyIPv4, pp);
          break;
        } on SocketException {
          continue;
        }
      }
    }
    if (server == null) throw const SocketException('no free port for guest share');
    _server = server;
    server.listen(_handle, onError: (Object e) => _log.fine('http error: $e'));
    _log.info('guest share listening on ${server.port}');
  }

  /// Offers [paths] to a guest. Replaces any previous session.
  Future<GuestSession> startSend(List<String> paths, {String? message}) async {
    await _ensureServer();
    final files = <GuestFile>[];
    var i = 0;
    for (final path in paths) {
      final f = File(path);
      if (!await f.exists()) continue;
      files.add(GuestFile(id: 'f${i++}', path: path, name: p.basename(path), size: await f.length()));
    }
    return _start(GuestMode.send, files, message);
  }

  /// Lets a guest upload files into [receiveDir].
  Future<GuestSession> startReceive({String? message}) async {
    await _ensureServer();
    await Directory(receiveDir).create(recursive: true);
    return _start(GuestMode.receive, const [], message);
  }

  GuestSession _start(GuestMode mode, List<GuestFile> files, String? message) {
    cancel();
    final s = GuestSession(
      token: base64Url(randomBytes(32)),
      mode: mode,
      expiresAt: DateTime.now().add(ttl),
      files: files,
      message: message,
    );
    _session = s;
    _expiry = Timer(ttl, () {
      if (identical(_session, s)) _emit(s, GuestEventKind.expired);
    });
    _emit(s, GuestEventKind.created);
    return s;
  }

  void cancel() {
    final s = _session;
    _expiry?.cancel();
    if (s != null && !s.cancelled && !s.isExpired) {
      s.cancelled = true;
      _emit(s, GuestEventKind.cancelled);
    }
    _session = null;
  }

  void _emit(GuestSession s, GuestEventKind kind, {String? fileName, int? bytes, String? remote, String? path}) {
    if (!_events.isClosed) {
      _events.add(GuestShareEvent(s, kind, fileName: fileName, bytes: bytes, remote: remote, path: path));
    }
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final segments = req.uri.pathSegments;
      if (segments.length < 2 || segments[0] != 's') {
        await _html(res, HttpStatus.notFound, guestErrorPage('PepoConnect'));
        return;
      }
      final token = segments[1];
      final s = _session;
      final remote = normalizeAddress(req.connectionInfo?.remoteAddress.address ?? '?');
      if (s == null || s.token != token || s.isExpired) {
        await _html(res, HttpStatus.gone, guestErrorPage('El enlace ha caducado. Pide otro en el PC.'));
        return;
      }
      if (s.boundRemote != null && s.boundRemote != remote) {
        await _html(res, HttpStatus.forbidden, guestErrorPage('Este enlace ya se está usando en otro dispositivo.'));
        return;
      }
      if (segments.length == 2) {
        if (s.boundRemote == null) {
          s.boundRemote = remote;
          _emit(s, GuestEventKind.opened, remote: remote);
        }
        final json = jsonEncode({
          'mode': s.mode.name,
          'host': hostName,
          'message': s.message,
          'files': s.files.map((f) => f.toJson()).toList(),
          'expiresAt': s.expiresAt.millisecondsSinceEpoch,
          'base': '/s/${s.token}',
        });
        await _html(res, HttpStatus.ok, guestSharePageHtml.replaceFirst('__SESSION_JSON__', json));
        return;
      }
      s.boundRemote ??= remote;
      if (segments[2] == 'file' && segments.length == 4 && s.mode == GuestMode.send) {
        await _serveFile(req, s, segments[3], remote);
        return;
      }
      if (segments[2] == 'upload' && s.mode == GuestMode.receive && (req.method == 'PUT' || req.method == 'POST')) {
        await _receiveUpload(req, s, remote);
        return;
      }
      await _html(res, HttpStatus.notFound, guestErrorPage('PepoConnect'));
    } catch (e, st) {
      _log.warning('guest request failed: $e', e, st);
      try {
        res.statusCode = HttpStatus.internalServerError;
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> _html(HttpResponse res, int status, String body) async {
    res.statusCode = status;
    res.headers.contentType = ContentType.html;
    res.headers.set('Cache-Control', 'no-store');
    res.write(body);
    await res.close();
  }

  Future<void> _serveFile(HttpRequest req, GuestSession s, String id, String remote) async {
    final res = req.response;
    final gf = s.files.where((f) => f.id == id).firstOrNull;
    if (gf == null) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final file = File(gf.path);
    final length = await file.length();
    var start = 0;
    var end = length - 1;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    if (range != null && range.startsWith('bytes=')) {
      final parts = range.substring(6).split('-');
      final a = int.tryParse(parts[0]);
      final b = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (a != null) {
        start = a;
        if (b != null && b < end) end = b;
      } else if (b != null) {
        start = length - b;
      }
      if (start < 0 || start > end) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await res.close();
        return;
      }
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$length');
    }
    res.headers.contentType = ContentType.binary;
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    res.headers.set('Content-Disposition', 'attachment; filename="${_asciiName(gf.name)}"; filename*=UTF-8\'\'${Uri.encodeComponent(gf.name)}');
    res.contentLength = end - start + 1;
    await res.addStream(file.openRead(start, end + 1));
    await res.close();
    if (start == 0 && end == length - 1) {
      s.downloads++;
      _emit(s, GuestEventKind.downloaded, fileName: gf.name, bytes: length, remote: remote);
    }
  }

  /// `::ffff:1.2.3.4` (IPv4 over a dual-stack socket) → `1.2.3.4`.
  static String normalizeAddress(String address) =>
      address.toLowerCase().startsWith('::ffff:') ? address.substring(7) : address;

  static String _asciiName(String name) =>
      name.replaceAll(RegExp(r'[^\x20-\x7E]'), '_').replaceAll('"', '_');

  Future<void> _receiveUpload(HttpRequest req, GuestSession s, String remote) async {
    final res = req.response;
    final rawName = req.uri.queryParameters['name'] ?? req.headers.value('X-File-Name') ?? 'archivo';
    final name = NameSanitizer.sanitize(rawName);
    final declared = req.contentLength;
    if (declared > maxUploadBytes) {
      res.statusCode = HttpStatus.requestEntityTooLarge;
      await res.close();
      return;
    }
    await Directory(receiveDir).create(recursive: true);
    final finalPath = NameSanitizer.uniquePath(receiveDir, name);
    final tmp = File('$finalPath.pepopart');
    final sink = tmp.openWrite();
    var received = 0;
    try {
      await for (final chunk in req) {
        received += chunk.length;
        if (received > maxUploadBytes) throw const HttpException('too large');
        sink.add(chunk);
      }
      await sink.close();
      await tmp.rename(finalPath);
      s.uploads++;
      _emit(s, GuestEventKind.uploaded, fileName: p.basename(finalPath), bytes: received, remote: remote, path: finalPath);
      res.statusCode = HttpStatus.ok;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({'ok': true, 'name': p.basename(finalPath), 'bytes': received}));
      await res.close();
    } catch (e) {
      await sink.close();
      try {
        await tmp.delete();
      } catch (_) {}
      _emit(s, GuestEventKind.uploadFailed, fileName: name, remote: remote);
      res.statusCode = e is HttpException ? HttpStatus.requestEntityTooLarge : HttpStatus.internalServerError;
      await res.close();
    }
  }

  Future<void> dispose() async {
    cancel();
    await _server?.close(force: true);
    _server = null;
    await _events.close();
  }
}
