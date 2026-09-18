// The Rust fast lane through its Dart bindings. Needs the library built:
//   cargo build --release --manifest-path packages/pepo_native/rust/Cargo.toml
// or PEPO_NATIVE_LIB pointing at it; otherwise the tests are skipped.
@Tags(['native'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pepo_core/src/native/native_bulk.dart';
import 'package:pepo_core/src/transfer/transfer_engine.dart' show sameHash;
import 'package:test/test.dart';
import 'package:xxh3/xxh3.dart';

import 'native_support.dart';

void main() {
  final lib = nativeLibraryPath();
  if (lib == null) {
    test('fast lane library not built: skipped', () {}, skip: 'build packages/pepo_native/rust');
    return;
  }

  late NativeBulk a;
  late NativeBulk b;
  late Directory dir;
  final sid = Uint8List.fromList(List.filled(16, 3));
  final key = Uint8List.fromList(List.filled(32, 5));

  setUp(() async {
    a = NativeBulk.tryLoad(libraryPath: lib)!;
    b = NativeBulk.tryLoad(libraryPath: lib)!;
    expect(a.listen(), greaterThan(0));
    a.addSession(sid, key);
    b.addSession(sid, key);
    dir = await Directory.systemTemp.createTemp('pepo_native_dart_');
  });

  tearDown(() async {
    a.dispose();
    b.dispose();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('xxh3 agrees with the Dart implementation', () {
    final data = Uint8List.fromList(List.generate(100000, (i) => (i * 31 + 7) % 256));
    final dart = (xxh3Stream()..update(data)).digestString();
    expect(sameHash(a.xxh3Hex(data), dart), isTrue);
    expect(sameHash(a.xxh3Hex(Uint8List(0)), (xxh3Stream()).digestString()), isTrue);
  });

  test('sends a file through the fast lane and hashes match', () async {
    final src = File(p.join(dir.path, 'src.bin'));
    final data = Uint8List.fromList(List.generate(6 * 1024 * 1024 + 13, (i) => (i * 7) % 253));
    await src.writeAsBytes(data);
    final dst = p.join(dir.path, 'dst.bin');
    final progress = <int>[];
    final recv = a.receive(sid: sid, key: key, transferId: 42, path: dst, size: data.length);
    final send = b.send(
      sid: sid,
      key: key,
      transferId: 42,
      path: src.path,
      host: '127.0.0.1',
      port: a.port,
      onProgress: progress.add,
    );
    final rs = await send.done.timeout(const Duration(seconds: 30));
    final rr = await recv.done.timeout(const Duration(seconds: 30));
    expect(rs.bytes, data.length);
    expect(rr.bytes, data.length);
    expect(rs.hashHex, rr.hashHex);
    expect(sameHash(rs.hashHex, (xxh3Stream()..update(data)).digestString()), isTrue);
    expect(await File(dst).readAsBytes(), data);
    expect(progress.last, data.length);
  });

  test('cancelling the receiver ends the sender with an error', () async {
    final src = File(p.join(dir.path, 'big.bin'));
    final rnd = Random(9);
    final raf = await src.open(mode: FileMode.write);
    final block = Uint8List.fromList(List.generate(1 << 20, (_) => rnd.nextInt(256)));
    for (var i = 0; i < 512; i++) {
      await raf.writeFrom(block);
    }
    await raf.close();
    final recv = a.receive(sid: sid, key: key, transferId: 7, path: p.join(dir.path, 'x.bin'));
    // Listen right away so an early failure is never an unhandled error.
    final recvOutcome = recv.done.then<Object?>((_) => null, onError: (Object e) => e);
    var seen = 0;
    final send = b.send(
      sid: sid,
      key: key,
      transferId: 7,
      path: src.path,
      host: '127.0.0.1',
      port: a.port,
      onProgress: (bytes) {
        seen = bytes;
        if (bytes > 0) recv.cancel();
      },
    );
    final sendOutcome = await send.done.then<Object?>((_) => null, onError: (Object e) => e);
    expect(sendOutcome, isA<NativeBulkException>());
    expect(await recvOutcome, isA<NativeBulkException>());
    expect(seen, greaterThan(0));
  });

  test('a job whose peer never connects fails on its own', () async {
    final recv = a.receive(sid: sid, key: key, transferId: 99, path: p.join(dir.path, 'never.bin'));
    await expectLater(
      recv.done.timeout(const Duration(seconds: 40)),
      throwsA(
        isA<NativeBulkException>().having((e) => e.message, 'message', contains('did not connect')),
      ),
    );
  });
}
