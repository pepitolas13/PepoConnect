import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:xxh3/xxh3.dart';

import '../net/frame.dart';

/// Signals a running stream to stop.
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Reads a file from an offset and yields encoded data frames ready for
/// `Socket.addStream`, hashing the bytes on the way.
class ChunkedFileReader {
  ChunkedFileReader({
    required this.path,
    required this.transferId,
    this.startOffset = 0,
    this.chunkSize = 256 * 1024,
  });

  final String path;
  final int transferId;
  final int startOffset;
  final int chunkSize;

  final XXH3State _hasher = xxh3Stream();
  int _sent = 0;

  /// Bytes emitted so far (excluding [startOffset]).
  int get bytesSent => _sent;

  /// Hash of the bytes emitted so far (xxh3-64, hex).
  String get hashHex => _hasher.digestString();

  /// Yields `[head, body]` pairs; each pair is one data frame. The frame
  /// head is emitted separately so the body is never copied.
  Stream<List<int>> frames({
    CancelToken? cancel,
    void Function(int bytesSent)? onProgress,
  }) async* {
    final raf = await File(path).open();
    try {
      if (startOffset > 0) await raf.setPosition(startOffset);
      var offset = startOffset;
      while (true) {
        if (cancel?.isCancelled ?? false) return;
        final chunk = await raf.read(chunkSize);
        if (chunk.isEmpty) return;
        _hasher.update(chunk);
        final frame = Frame.data(transferId: transferId, offset: offset, chunk: chunk);
        yield frame.encodeHead();
        yield chunk;
        offset += chunk.length;
        _sent += chunk.length;
        onProgress?.call(_sent);
      }
    } finally {
      await raf.close();
    }
  }

  /// xxh3 of the last `min(length, window)` bytes before [offset] of a file,
  /// used to check that both sides agree on the resume point.
  static Future<String> tailHash(String path, int offset,
      {int window = 1024 * 1024}) async {
    if (offset <= 0) return '';
    final start = offset > window ? offset - window : 0;
    final raf = await File(path).open();
    try {
      await raf.setPosition(start);
      final h = xxh3Stream();
      var remaining = offset - start;
      while (remaining > 0) {
        final chunk = await raf.read(remaining > 262144 ? 262144 : remaining);
        if (chunk.isEmpty) break;
        h.update(chunk);
        remaining -= chunk.length;
      }
      return h.digestString();
    } finally {
      await raf.close();
    }
  }
}

/// Incremental xxh3 helper for the receiving side.
class StreamHasher {
  final XXH3State _state = xxh3Stream();
  int _bytes = 0;

  int get bytes => _bytes;
  void update(Uint8List data) {
    _state.update(data);
    _bytes += data.length;
  }

  String get hashHex => _state.digestString();
}
