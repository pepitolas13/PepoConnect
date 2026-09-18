import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// GitHub endpoints of the project.
const String repositoryUrl = 'https://github.com/pepitolas13/PepoConnect';
const String releasesPageUrl = '$repositoryUrl/releases';
const String latestReleaseApiUrl =
    'https://api.github.com/repos/pepitolas13/PepoConnect/releases/latest';

/// A release asset hosted by this project's GitHub repository.
@immutable
class UpdateAsset {
  const UpdateAsset({required this.name, required this.url, required this.size});

  final String name;
  final String url;
  final int size;

  factory UpdateAsset.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final url = json['browser_download_url'];
    final size = json['size'];
    if (name is! String ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(name) ||
        url is! String ||
        size is! int ||
        size <= 0 ||
        size > 2 * 1024 * 1024 * 1024 ||
        (json['state'] != null && json['state'] != 'uploaded')) {
      throw const FormatException('Invalid release asset');
    }
    final uri = Uri.tryParse(url);
    final parts = uri?.pathSegments ?? const <String>[];
    if (!_isProjectUrl(uri) ||
        parts.length != 6 ||
        parts[2] != 'releases' ||
        parts[3] != 'download' ||
        !_stableTag(parts[4]) ||
        parts[5] != name) {
      throw const FormatException('Untrusted release asset URL');
    }
    return UpdateAsset(name: name, url: url, size: size);
  }

  Map<String, dynamic> toJson() => {'name': name, 'browser_download_url': url, 'size': size};
}

bool _isProjectUrl(Uri? uri) =>
    uri != null &&
    uri.scheme == 'https' &&
    uri.host == 'github.com' &&
    uri.port == 443 &&
    uri.userInfo.isEmpty &&
    !uri.hasQuery &&
    !uri.hasFragment &&
    uri.pathSegments.length >= 2 &&
    uri.pathSegments[0] == 'pepitolas13' &&
    uri.pathSegments[1] == 'PepoConnect';

bool _stableTag(String value) =>
    RegExp(r'^[vV]?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\+[0-9A-Za-z.-]+)?$')
        .hasMatch(value);

/// Validated stable release metadata, shared by background and manual checks.
@immutable
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.latest,
    required this.url,
    required this.isNewer,
    this.assets = const [],
    this.tag,
  });

  /// Tag of the latest release, without the leading `v`.
  final String latest;

  /// Web page of that release.
  final String url;
  final bool isNewer;
  final List<UpdateAsset> assets;
  final String? tag;

  UpdateAsset? assetNamed(String name) {
    for (final asset in assets) {
      if (asset.name == name) return asset;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'tag_name': tag ?? latest,
    'html_url': url,
    'assets': assets.map((a) => a.toJson()).toList(),
  };

  /// Reads the `releases/latest` payload of the GitHub API.
  factory UpdateCheckResult.fromJson(Map<String, dynamic> json, {required String current}) {
    final rawTag = json['tag_name'];
    if (rawTag is! String ||
        !_stableTag(rawTag) ||
        json['draft'] == true ||
        json['prerelease'] == true) {
      throw const FormatException('Expected a stable release');
    }
    final latest = normalizeVersion(rawTag);
    final url = json['html_url'] ?? releasesPageUrl;
    final uri = url is String ? Uri.tryParse(url) : null;
    final parts = uri?.pathSegments ?? const <String>[];
    if (!_isProjectUrl(uri) ||
        !(url == releasesPageUrl ||
            (parts.length == 5 &&
                parts[2] == 'releases' &&
                parts[3] == 'tag' &&
                parts[4] == rawTag))) {
      throw const FormatException('Untrusted release URL');
    }
    final rawAssets = json['assets'] ?? const <dynamic>[];
    if (rawAssets is! List) throw const FormatException('Invalid release assets');
    final assets = <UpdateAsset>[];
    final names = <String>{};
    for (final raw in rawAssets) {
      if (raw is! Map<String, dynamic>) throw const FormatException('Invalid release asset');
      final asset = UpdateAsset.fromJson(raw);
      if (!names.add(asset.name) || Uri.parse(asset.url).pathSegments[4] != rawTag) {
        throw const FormatException('Duplicate asset or mismatched release');
      }
      assets.add(asset);
    }
    return UpdateCheckResult(
      latest: latest,
      url: url as String,
      tag: rawTag,
      assets: List.unmodifiable(assets),
      isNewer: compareVersions(latest, current) > 0,
    );
  }
}

/// `v1.2.3+7` → `1.2.3`: drops a leading `v`, the build number and any
/// pre-release suffix.
String normalizeVersion(String version) {
  var v = version.trim();
  if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
  final cut = v.indexOf(RegExp(r'[+-]'));
  if (cut >= 0) v = v.substring(0, cut);
  return v;
}

/// Numeric, dotted comparison: negative when [a] is older than [b], zero when
/// they are the same, positive when [a] is newer. Missing components count
/// as zero (`1.2` equals `1.2.0`); non-numeric ones count as zero too.
int compareVersions(String a, String b) {
  final pa = normalizeVersion(a).split('.');
  final pb = normalizeVersion(b).split('.');
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? int.tryParse(pa[i]) ?? 0 : 0;
    final y = i < pb.length ? int.tryParse(pb[i]) ?? 0 : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// Asks GitHub for the latest release and compares it with [currentVersion].
/// Throws on network or parsing errors; callers show a plain "could not
/// check" message.
Future<UpdateCheckResult> checkForUpdates({
  required String currentVersion,
  HttpClient? client,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final http = client ?? HttpClient();
  http.connectionTimeout = timeout;
  try {
    final request = await http.getUrl(Uri.parse(latestReleaseApiUrl)).timeout(timeout);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    request.headers.set(HttpHeaders.userAgentHeader, 'PepoConnect/$currentVersion');
    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}', uri: request.uri);
    }
    var bytes = 0;
    final body = await response
        .map((chunk) {
          bytes += chunk.length;
          if (bytes > 2 * 1024 * 1024) throw const FormatException('Release metadata is too large');
          return chunk;
        })
        .transform(utf8.decoder)
        .join()
        .timeout(timeout);
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) throw const FormatException('unexpected payload');
    return UpdateCheckResult.fromJson(json, current: currentVersion);
  } finally {
    if (client == null) http.close(force: true);
  }
}
