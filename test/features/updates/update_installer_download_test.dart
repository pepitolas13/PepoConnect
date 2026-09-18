import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/features/updates/update_download.dart';

void main() {
  final asset = Uri.parse(
    'https://github.com/pepitolas13/PepoConnect/releases/download/v1.2.3/app.exe',
  );
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('pepo-download-test-'));
  tearDown(() async => temp.delete(recursive: true));

  test('requires exactly one well formed checksum for the named asset', () {
    final hash = sha256.convert([1, 2, 3]).toString();
    expect(checksumFor('$hash  app.exe\n', 'app.exe'), hash);
    expect(() => checksumFor('$hash  another.exe\n', 'app.exe'), throwsFormatException);
    expect(() => checksumFor('$hash  app.exe\n$hash  app.exe', 'app.exe'), throwsFormatException);
    expect(() => checksumFor('not-a-hash  app.exe', 'app.exe'), throwsFormatException);
  });

  test('release paths must match and initial asset URLs must be official HTTPS', () {
    expect(isOfficialAsset(asset, 'app.exe'), isTrue);
    expect(isOfficialAsset(asset.replace(scheme: 'http'), 'app.exe'), isFalse);
    expect(isOfficialAsset(asset.replace(host: 'github.com.evil.test'), 'app.exe'), isFalse);
    expect(isOfficialAsset(asset, 'different.exe'), isFalse);
    expect(
      sameAssetRelease(
        asset,
        asset.replace(path: asset.path.replaceFirst('app.exe', 'SHA256SUMS.txt')),
      ),
      isTrue,
    );
    expect(
      sameAssetRelease(asset, asset.replace(path: asset.path.replaceFirst('v1.2.3', 'v2.0.0'))),
      isFalse,
    );
  });

  test('downloads exact bytes and verifies checksum', () async {
    final transport = FakeTransport(
      (uri) async => UpdateResponse(200, {}, Stream.value([1, 2, 3])),
    );
    final download = VerifiedUpdateDownload(transport: transport);
    final file = File('${temp.path}/asset');
    await download.fetch(asset, file, expectedSize: 3, maxBytes: 5);
    await download.verify(file, sha256.convert([1, 2, 3]).toString());
    expect(await file.readAsBytes(), [1, 2, 3]);
    await expectLater(
      download.verify(file, '0' * 64),
      throwsA(isA<UpdateDownloadException>().having((e) => e.code, 'code', 'verification')),
    );
    download.close();
  });

  test('rejects a redirect to an unrelated or insecure host before requesting it', () async {
    for (final location in [
      'https://evil.test/file',
      'http://release-assets.githubusercontent.com/file',
    ]) {
      var calls = 0;
      final download = VerifiedUpdateDownload(
        transport: FakeTransport((uri) async {
          calls++;
          return UpdateResponse(302, {'location': location}, const Stream.empty());
        }),
      );
      await expectLater(
        download.fetch(asset, File('${temp.path}/bad'), expectedSize: 3, maxBytes: 5),
        throwsA(isA<UpdateDownloadException>()),
      );
      expect(calls, 1);
      download.close();
    }
  });

  test('rejects truncated and oversized streams and deletes partial download', () async {
    for (final bytes in [
      [1, 2],
      [1, 2, 3, 4],
    ]) {
      final file = File('${temp.path}/bad');
      final download = VerifiedUpdateDownload(
        transport: FakeTransport((uri) async => UpdateResponse(200, {}, Stream.value(bytes))),
      );
      await expectLater(
        download.fetch(asset, file, expectedSize: 3, maxBytes: 3),
        throwsA(isA<UpdateDownloadException>()),
      );
      expect(await file.exists(), isFalse);
      download.close();
    }
  });

  test('cancellation interrupts a stalled body and removes partial data', () async {
    final body = StreamController<List<int>>();
    final download = VerifiedUpdateDownload(
      transport: FakeTransport((uri) async => UpdateResponse(200, {}, body.stream)),
    );
    final file = File('${temp.path}/cancelled');
    final operation = download.fetch(asset, file, expectedSize: 3, maxBytes: 3);
    final assertion = expectLater(
      operation,
      throwsA(isA<UpdateDownloadException>().having((e) => e.code, 'code', 'cancelled')),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    download.cancel();
    await assertion.timeout(const Duration(seconds: 2));
    expect(await file.exists(), isFalse);
    await body.close();
    download.close();
  });

  test('checksum stream and announced size are bounded', () async {
    final bytes = utf8.encode('0' * 256);
    final download = VerifiedUpdateDownload(
      transport: FakeTransport(
        (uri) async => UpdateResponse(200, {'content-length': '999'}, Stream.value(bytes)),
      ),
    );
    await expectLater(
      download.fetch(asset, File('${temp.path}/bad'), expectedSize: 256, maxBytes: 512),
      throwsA(isA<UpdateDownloadException>()),
    );
    download.close();
  });
}

class FakeTransport implements UpdateTransport {
  FakeTransport(this.openResponse);
  final Future<UpdateResponse> Function(Uri) openResponse;
  @override
  Future<UpdateResponse> open(Uri uri) => openResponse(uri);
  @override
  void close() {}
}
