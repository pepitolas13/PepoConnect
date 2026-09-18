import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// GitHub endpoints of the project.
const String repositoryUrl = 'https://github.com/pepitolas13/PepoConnect';
const String releasesPageUrl = '$repositoryUrl/releases';
const String latestReleaseApiUrl =
    'https://api.github.com/repos/pepitolas13/PepoConnect/releases/latest';

/// Outcome of a release check. Nothing is downloaded or installed: the user
/// gets a link to the release page.
@immutable
class UpdateCheckResult {
  const UpdateCheckResult({required this.latest, required this.url, required this.isNewer});

  /// Tag of the latest release, without the leading `v`.
  final String latest;

  /// Web page of that release.
  final String url;
  final bool isNewer;

  /// Reads the `releases/latest` payload of the GitHub API.
  factory UpdateCheckResult.fromJson(Map<String, dynamic> json, {required String current}) {
    final tag = normalizeVersion(json['tag_name'] as String? ?? '');
    final url = json['html_url'] as String? ?? releasesPageUrl;
    return UpdateCheckResult(latest: tag, url: url, isNewer: compareVersions(tag, current) > 0);
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
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    request.headers.set(HttpHeaders.userAgentHeader, 'PepoConnect/$currentVersion');
    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}', uri: request.uri);
    }
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) throw const FormatException('unexpected payload');
    return UpdateCheckResult.fromJson(json, current: currentVersion);
  } finally {
    if (client == null) http.close(force: true);
  }
}
