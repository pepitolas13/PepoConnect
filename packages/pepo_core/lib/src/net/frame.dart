import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Wire frame kinds.
enum FrameKind {
  control(1),
  data(2),
  ping(3),
  pong(4);

  const FrameKind(this.code);
  final int code;

  static FrameKind? fromCode(int code) => switch (code) {
    1 => FrameKind.control,
    2 => FrameKind.data,
    3 => FrameKind.ping,
    4 => FrameKind.pong,
    _ => null,
  };
}

/// Thrown when a peer sends bytes that do not form a valid frame.
class FrameFormatException implements Exception {
  FrameFormatException(this.message);
  final String message;

  @override
  String toString() => 'FrameFormatException: $message';
}

/// A protocol frame.
///
/// Layout (little-endian):
/// ```
/// u32 len      bytes following this field (8 + hdrLen + bodyLen)
/// u8  kind     FrameKind.code
/// u8  flags    reserved, 0
/// u16 hdrLen   header length
/// u32 reqId    request correlation id, 0 = event
/// [hdrLen] header   JSON (control) or binary (data)
/// [rest]   body
/// ```
class Frame {
  Frame({
    required this.kind,
    required this.header,
    required this.body,
    this.reqId = 0,
    this.flags = 0,
  });

  /// Bytes before the header: len(4) kind(1) flags(1) hdrLen(2) reqId(4).
  static const int fixedHeaderSize = 12;

  /// Maximum total frame size (4 + len).
  static const int maxFrameBytes = 16 * 1024 * 1024 + fixedHeaderSize;

  /// Maximum JSON header size for control frames.
  static const int maxJsonHeader = 64 * 1024;

  /// Binary header size of data frames: transferId(4) offset(8) len(4).
  static const int dataHeaderSize = 16;

  static final Uint8List _empty = Uint8List(0);

  final FrameKind kind;
  final int flags;
  final int reqId;
  final Uint8List header;
  final Uint8List body;

  /// Ping frame.
  factory Frame.ping() => Frame(kind: FrameKind.ping, header: _empty, body: _empty);

  /// Pong frame.
  factory Frame.pong() => Frame(kind: FrameKind.pong, header: _empty, body: _empty);

  /// Control frame carrying a JSON header `{"t": type, ...data}` and an
  /// optional binary body.
  factory Frame.control(String type, {Map<String, dynamic>? data, int reqId = 0, Uint8List? body}) {
    final json = <String, dynamic>{'t': type, ...?data};
    final header = utf8.encode(jsonEncode(json));
    if (header.length > maxJsonHeader) {
      throw FrameFormatException('control header too large: ${header.length}');
    }
    return Frame(kind: FrameKind.control, header: header, body: body ?? _empty, reqId: reqId);
  }

  /// Data frame for a transfer chunk.
  factory Frame.data({required int transferId, required int offset, required Uint8List chunk}) {
    final header = Uint8List(dataHeaderSize);
    final bd = ByteData.sublistView(header);
    bd.setUint32(0, transferId, Endian.little);
    bd.setUint64(4, offset, Endian.little);
    bd.setUint32(12, chunk.length, Endian.little);
    return Frame(kind: FrameKind.data, header: header, body: chunk);
  }

  /// Total encoded size.
  int get encodedLength => fixedHeaderSize + header.length + body.length;

  /// Encodes the frame into a single buffer.
  Uint8List encode() {
    final out = Uint8List(encodedLength);
    _writeFixedHeader(out);
    out.setRange(fixedHeaderSize, fixedHeaderSize + header.length, header);
    out.setRange(fixedHeaderSize + header.length, out.length, body);
    return out;
  }

  /// Encodes only the fixed header + header so the body can be written
  /// separately without copying (bulk transfers).
  Uint8List encodeHead() {
    final out = Uint8List(fixedHeaderSize + header.length);
    _writeFixedHeader(out);
    out.setRange(fixedHeaderSize, out.length, header);
    return out;
  }

  void _writeFixedHeader(Uint8List out) {
    final bd = ByteData.sublistView(out);
    bd.setUint32(0, 8 + header.length + body.length, Endian.little);
    out[4] = kind.code;
    out[5] = flags;
    bd.setUint16(6, header.length, Endian.little);
    bd.setUint32(8, reqId, Endian.little);
  }

  /// Parses a complete frame buffer (exactly one frame).
  static Frame parse(Uint8List buf) {
    if (buf.length < fixedHeaderSize) {
      throw FrameFormatException('short frame: ${buf.length}');
    }
    final bd = ByteData.sublistView(buf);
    final len = bd.getUint32(0, Endian.little);
    if (4 + len != buf.length) {
      throw FrameFormatException('length mismatch: $len vs ${buf.length - 4}');
    }
    final kind = FrameKind.fromCode(buf[4]);
    if (kind == null) throw FrameFormatException('unknown kind ${buf[4]}');
    final flags = buf[5];
    final hdrLen = bd.getUint16(6, Endian.little);
    final reqId = bd.getUint32(8, Endian.little);
    if (8 + hdrLen > len) throw FrameFormatException('header exceeds frame');
    if (kind == FrameKind.control && hdrLen > maxJsonHeader) {
      throw FrameFormatException('control header too large: $hdrLen');
    }
    if (kind == FrameKind.data && hdrLen != dataHeaderSize) {
      throw FrameFormatException('bad data header size: $hdrLen');
    }
    if ((kind == FrameKind.ping || kind == FrameKind.pong) && len != 8) {
      throw FrameFormatException('ping/pong must be empty');
    }
    final header = Uint8List.sublistView(buf, fixedHeaderSize, fixedHeaderSize + hdrLen);
    final body = Uint8List.sublistView(buf, fixedHeaderSize + hdrLen, buf.length);
    return Frame(kind: kind, flags: flags, reqId: reqId, header: header, body: body);
  }

  @override
  String toString() =>
      'Frame(${kind.name}, reqId=$reqId, hdr=${header.length}, body=${body.length})';
}

/// Decoded view of a control frame.
class ControlMessage {
  ControlMessage({required this.type, required this.data, required this.reqId, required this.body});

  final String type;
  final Map<String, dynamic> data;
  final int reqId;
  final Uint8List body;

  static ControlMessage fromFrame(Frame frame) {
    if (frame.kind != FrameKind.control) {
      throw FrameFormatException('not a control frame');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(frame.header));
    } on FormatException catch (e) {
      throw FrameFormatException('invalid JSON header: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw FrameFormatException('JSON header is not an object');
    }
    final type = decoded['t'];
    if (type is! String || type.isEmpty) {
      throw FrameFormatException('missing message type');
    }
    return ControlMessage(type: type, data: decoded, reqId: frame.reqId, body: frame.body);
  }

  /// Typed accessors with sane failures.
  String str(String key) {
    final v = data[key];
    if (v is! String) throw FrameFormatException('field $key must be string');
    return v;
  }

  String? optStr(String key) => data[key] as String?;

  int integer(String key) {
    final v = data[key];
    if (v is! int) throw FrameFormatException('field $key must be int');
    return v;
  }

  int? optInt(String key) => data[key] as int?;

  bool flag(String key, {bool defaultValue = false}) => data[key] as bool? ?? defaultValue;

  List<T> list<T>(String key) => (data[key] as List<dynamic>? ?? const []).cast<T>();

  Map<String, dynamic>? map(String key) => data[key] as Map<String, dynamic>?;

  @override
  String toString() => 'ControlMessage($type, reqId=$reqId, body=${body.length})';
}

/// Decoded view of a data frame.
class DataChunk {
  DataChunk({required this.transferId, required this.offset, required this.bytes});

  final int transferId;
  final int offset;
  final Uint8List bytes;

  static DataChunk fromFrame(Frame frame) {
    if (frame.kind != FrameKind.data) throw FrameFormatException('not a data frame');
    final bd = ByteData.sublistView(frame.header);
    final len = bd.getUint32(12, Endian.little);
    if (len != frame.body.length) {
      throw FrameFormatException('data length mismatch: $len vs ${frame.body.length}');
    }
    return DataChunk(
      transferId: bd.getUint32(0, Endian.little),
      offset: bd.getUint64(4, Endian.little),
      bytes: frame.body,
    );
  }
}

/// Incremental frame decoder: feed socket chunks, get complete frames.
///
/// Each frame is assembled in exactly one buffer allocated at its final size,
/// so bulk data is copied once regardless of how TCP fragments it.
class FrameDecoder {
  final Uint8List _head = Uint8List(Frame.fixedHeaderSize);
  int _headFilled = 0;
  Uint8List? _frame;
  int _frameFilled = 0;

  /// Bytes currently buffered for an incomplete frame.
  int get pendingBytes => _frame == null ? _headFilled : _frameFilled;

  /// Feeds [chunk] and invokes [onFrame] for every completed frame, in order.
  void addChunk(Uint8List chunk, void Function(Frame frame) onFrame) {
    var off = 0;
    while (off < chunk.length) {
      final frame = _frame;
      if (frame == null) {
        final take = min(Frame.fixedHeaderSize - _headFilled, chunk.length - off);
        _head.setRange(_headFilled, _headFilled + take, chunk, off);
        _headFilled += take;
        off += take;
        if (_headFilled < Frame.fixedHeaderSize) return;
        final len = ByteData.sublistView(_head).getUint32(0, Endian.little);
        if (len < 8) throw FrameFormatException('frame too short: $len');
        if (4 + len > Frame.maxFrameBytes) {
          throw FrameFormatException('frame too large: $len');
        }
        final kind = FrameKind.fromCode(_head[4]);
        if (kind == null) throw FrameFormatException('unknown kind ${_head[4]}');
        final buf = Uint8List(4 + len);
        buf.setRange(0, Frame.fixedHeaderSize, _head);
        _headFilled = 0;
        if (buf.length == Frame.fixedHeaderSize) {
          // Empty frame (ping/pong): complete as soon as the header is in.
          onFrame(Frame.parse(buf));
          continue;
        }
        _frame = buf;
        _frameFilled = Frame.fixedHeaderSize;
        continue;
      }
      final take = min(frame.length - _frameFilled, chunk.length - off);
      frame.setRange(_frameFilled, _frameFilled + take, chunk, off);
      _frameFilled += take;
      off += take;
      if (_frameFilled == frame.length) {
        _frame = null;
        _frameFilled = 0;
        onFrame(Frame.parse(frame));
      }
    }
  }

  /// Discards any partial state.
  void reset() {
    _headFilled = 0;
    _frame = null;
    _frameFilled = 0;
  }
}
