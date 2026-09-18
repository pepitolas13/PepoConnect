import 'dart:math';
import 'dart:typed_data';

import 'package:pepo_core/src/net/frame.dart';
import 'package:test/test.dart';

void main() {
  Uint8List bytes(int n, [int seed = 1]) {
    final r = Random(seed);
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  List<Frame> decodeAll(List<Uint8List> chunks) {
    final dec = FrameDecoder();
    final out = <Frame>[];
    for (final c in chunks) {
      dec.addChunk(c, out.add);
    }
    expect(dec.pendingBytes, 0);
    return out;
  }

  test('control frame round trip', () {
    final f = Frame.control('hello', data: {'v': 1, 'name': 'Pixel ñ'}, reqId: 7, body: bytes(100));
    final decoded = decodeAll([f.encode()]);
    expect(decoded, hasLength(1));
    final m = ControlMessage.fromFrame(decoded.single);
    expect(m.type, 'hello');
    expect(m.integer('v'), 1);
    expect(m.str('name'), 'Pixel ñ');
    expect(m.reqId, 7);
    expect(m.body, bytes(100));
  });

  test('data frame round trip and head/body split encoding', () {
    final chunk = bytes(256 * 1024, 3);
    final f = Frame.data(transferId: 42, offset: 1 << 40, chunk: chunk);
    final decoded = decodeAll([f.encodeHead(), chunk]);
    final d = DataChunk.fromFrame(decoded.single);
    expect(d.transferId, 42);
    expect(d.offset, 1 << 40);
    expect(d.bytes, chunk);
  });

  test('ping and pong', () {
    final decoded = decodeAll([Frame.ping().encode(), Frame.pong().encode()]);
    expect(decoded.map((f) => f.kind), [FrameKind.ping, FrameKind.pong]);
  });

  test('fragmentation into tiny chunks and coalesced frames', () {
    final frames = [
      Frame.control('a', data: {'x': 1}),
      Frame.data(transferId: 1, offset: 0, chunk: bytes(1000)),
      Frame.ping(),
      Frame.control('b', body: bytes(33)),
    ];
    final all = BytesBuilder();
    for (final f in frames) {
      all.add(f.encode());
    }
    final buf = all.takeBytes();
    for (final size in [1, 2, 3, 5, 7, 64, 4096]) {
      final chunks = <Uint8List>[];
      for (var i = 0; i < buf.length; i += size) {
        chunks.add(Uint8List.sublistView(buf, i, min(i + size, buf.length)));
      }
      final decoded = decodeAll(chunks);
      expect(decoded, hasLength(4), reason: 'chunk size $size');
      expect(decoded[0].kind, FrameKind.control);
      expect(DataChunk.fromFrame(decoded[1]).bytes, bytes(1000));
      expect(decoded[2].kind, FrameKind.ping);
      expect(ControlMessage.fromFrame(decoded[3]).body, bytes(33));
    }
  });

  test('rejects malformed input', () {
    expect(
      () => decodeAll([
        Uint8List.fromList([9, 0, 0, 0, 99, 0, 0, 0, 0, 0, 0, 0, 0]),
      ]),
      throwsA(isA<FrameFormatException>()),
    );
    final huge = Uint8List(12);
    ByteData.sublistView(huge).setUint32(0, 0xFFFFFFFF, Endian.little);
    expect(() => decodeAll([huge]), throwsA(isA<FrameFormatException>()));
    expect(
      () => Frame.control('x', data: {'p': 'y' * 70000}),
      throwsA(isA<FrameFormatException>()),
    );
    final bad = Frame.control('x').encode();
    bad[4] = FrameKind.data.code; // wrong header size for a data frame
    expect(() => decodeAll([bad]), throwsA(isA<FrameFormatException>()));
  });

  test('fuzz: random frames through random chunking', () {
    final r = Random(99);
    for (var round = 0; round < 200; round++) {
      final frames = List.generate(1 + r.nextInt(6), (i) {
        switch (r.nextInt(3)) {
          case 0:
            return Frame.control(
              't$i',
              data: {'i': i},
              reqId: r.nextInt(1 << 31),
              body: bytes(r.nextInt(5000), i),
            );
          case 1:
            return Frame.data(
              transferId: i,
              offset: r.nextInt(1 << 30),
              chunk: bytes(r.nextInt(20000), i + 1),
            );
          default:
            return r.nextBool() ? Frame.ping() : Frame.pong();
        }
      });
      final all = BytesBuilder();
      for (final f in frames) {
        all.add(f.encode());
      }
      final buf = all.takeBytes();
      final chunks = <Uint8List>[];
      var i = 0;
      while (i < buf.length) {
        final n = 1 + r.nextInt(3000);
        chunks.add(Uint8List.sublistView(buf, i, min(i + n, buf.length)));
        i += n;
      }
      final decoded = decodeAll(chunks);
      expect(decoded.length, frames.length);
      for (var k = 0; k < frames.length; k++) {
        expect(decoded[k].kind, frames[k].kind);
        expect(decoded[k].reqId, frames[k].reqId);
        expect(decoded[k].header, frames[k].header);
        expect(decoded[k].body, frames[k].body);
      }
    }
  });
}
