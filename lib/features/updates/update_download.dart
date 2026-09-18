import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class UpdateResponse {
  const UpdateResponse(this.status, this.headers, this.body);
  final int status;
  final Map<String, String> headers;
  final Stream<List<int>> body;
}

/// A narrow transport boundary lets tests exercise the real limits and verifier.
abstract class UpdateTransport {
  Future<UpdateResponse> open(Uri uri);
  void close();
}

class HttpUpdateTransport implements UpdateTransport {
  HttpUpdateTransport() : _client = HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 20);
    _client.autoUncompress = false;
  }
  final HttpClient _client;
  @override
  Future<UpdateResponse> open(Uri uri) async {
    final request = await _client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.userAgentHeader, 'PepoConnect updater');
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close();
    final headers = <String, String>{};
    response.headers.forEach((name, values) => headers[name] = values.join(','));
    return UpdateResponse(response.statusCode, headers, response);
  }

  @override
  void close() => _client.close(force: true);
}

bool isOfficialAsset(Uri uri, String name) {
  final parts = uri.pathSegments;
  return uri.scheme == 'https' &&
      uri.host == 'github.com' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      parts.length == 6 &&
      parts[0] == 'pepitolas13' &&
      parts[1] == 'PepoConnect' &&
      parts[2] == 'releases' &&
      parts[3] == 'download' &&
      parts[4].isNotEmpty &&
      parts[5] == name &&
      !name.contains('/') &&
      !name.contains('\\');
}

bool sameAssetRelease(Uri a, Uri b) =>
    isOfficialAsset(a, a.pathSegments.last) &&
    isOfficialAsset(b, b.pathSegments.last) &&
    a.pathSegments.take(5).join('/') == b.pathSegments.take(5).join('/');

bool _trustedRedirect(Uri uri, Uri initial) {
  if (uri.scheme != 'https' || uri.port != 443 || uri.userInfo.isNotEmpty || uri.hasFragment) {
    return false;
  }
  if (uri.host == 'github.com') {
    return sameAssetRelease(initial, uri) && uri.pathSegments.last == initial.pathSegments.last;
  }
  return uri.host == 'release-assets.githubusercontent.com' ||
      uri.host == 'objects.githubusercontent.com';
}

/// sha256sum's text and binary formats, with no ambiguity or duplicate names.
String checksumFor(String manifest, String assetName) {
  final checksums = <String, String>{};
  for (final line in const LineSplitter().convert(manifest)) {
    if (line.isEmpty) continue;
    final match = RegExp(r'^([a-fA-F0-9]{64}) [ *]([^\r\n]+)$').firstMatch(line);
    if (match == null) throw const FormatException('Invalid checksum manifest');
    final name = match.group(2)!;
    if (name.contains('/') || name.contains('\\') || checksums.containsKey(name)) {
      throw const FormatException('Ambiguous checksum manifest');
    }
    checksums[name] = match.group(1)!.toLowerCase();
  }
  final checksum = checksums[assetName];
  if (checksum == null) throw const FormatException('Release has no checksum for this asset');
  return checksum;
}

class VerifiedUpdateDownload {
  VerifiedUpdateDownload({
    UpdateTransport? transport,
    this.idleTimeout = const Duration(seconds: 30),
    this.totalTimeout = const Duration(minutes: 15),
  }) : _transport = transport ?? HttpUpdateTransport();
  final UpdateTransport _transport;
  final Duration idleTimeout;
  final Duration totalTimeout;
  final Completer<void> _cancel = Completer<void>();
  bool get isCancelled => _cancel.isCompleted;

  void cancel() {
    if (!_cancel.isCompleted) _cancel.complete();
    _transport.close();
  }

  void close() => _transport.close();

  void checkCancelled() {
    if (isCancelled) throw const UpdateDownloadException('cancelled', 'Update cancelled');
  }

  Future<T> _bounded<T>(Future<T> operation, {Duration? timeout}) {
    checkCancelled();
    return Future.any<T>([
      operation.timeout(timeout ?? idleTimeout),
      _cancel.future.then<T>(
        (_) => throw const UpdateDownloadException('cancelled', 'Update cancelled'),
      ),
    ]);
  }

  Future<void> fetch(
    Uri uri,
    File destination, {
    required int expectedSize,
    required int maxBytes,
    void Function(int received)? onBytes,
  }) async {
    if (uri.pathSegments.isEmpty ||
        !isOfficialAsset(uri, uri.pathSegments.last) ||
        expectedSize < 1 ||
        expectedSize > maxBytes) {
      throw const UpdateDownloadException('verification', 'Invalid release asset');
    }
    RandomAccessFile? output;
    StreamIterator<List<int>>? iterator;
    final watch = Stopwatch()..start();
    try {
      var current = uri;
      UpdateResponse? response;
      for (var hop = 0; hop <= 5; hop++) {
        checkCancelled();
        final next = await _bounded(_transport.open(current));
        response = next;
        if (![301, 302, 303, 307, 308].contains(next.status)) break;
        final location = next.headers['location'];
        await next.body.listen((_) {}).cancel();
        if (location == null || hop == 5) {
          throw const UpdateDownloadException('download', 'Invalid download redirect');
        }
        current = current.resolve(location);
        if (!_trustedRedirect(current, uri)) {
          throw const UpdateDownloadException('verification', 'Untrusted download redirect');
        }
      }
      if (response == null || response.status != 200) {
        throw UpdateDownloadException('download', 'Download failed (${response?.status})');
      }
      final encoding = response.headers['content-encoding'];
      if (encoding != null && encoding != 'identity') {
        throw const UpdateDownloadException('verification', 'Unexpected download encoding');
      }
      final announced = response.headers['content-length'];
      if (announced != null && int.tryParse(announced) != expectedSize) {
        throw const UpdateDownloadException('verification', 'Release asset size changed');
      }
      await destination.parent.create(recursive: true);
      output = await destination.open(mode: FileMode.write);
      iterator = StreamIterator(response.body);
      var received = 0;
      while (await _bounded(iterator.moveNext())) {
        checkCancelled();
        if (watch.elapsed > totalTimeout) throw TimeoutException('Update download timed out');
        final chunk = iterator.current;
        received += chunk.length;
        if (received > expectedSize || received > maxBytes) {
          throw const UpdateDownloadException(
            'verification',
            'Release asset exceeds expected size',
          );
        }
        await output.writeFrom(chunk);
        onBytes?.call(received);
      }
      if (received != expectedSize) {
        throw const UpdateDownloadException('verification', 'Incomplete release asset');
      }
      await output.flush();
      await output.close();
      output = null;
    } catch (error) {
      await output?.close();
      output = null;
      if (await destination.exists()) await destination.delete();
      checkCancelled();
      if (error is UpdateDownloadException) rethrow;
      throw UpdateDownloadException('download', error.toString());
    } finally {
      await iterator?.cancel();
      await output?.close();
    }
  }

  Future<void> verify(File file, String expected) async {
    checkCancelled();
    final digest = await _bounded(
      sha256.bind(file.openRead()).first,
      timeout: const Duration(minutes: 3),
    );
    checkCancelled();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expected) || digest.toString() != expected) {
      throw const UpdateDownloadException('verification', 'The update checksum does not match');
    }
  }
}
