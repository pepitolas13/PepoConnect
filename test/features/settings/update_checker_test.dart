import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/features/settings/update_checker.dart';

void main() {
  test('normalizeVersion drops the v prefix, build number and pre-release', () {
    expect(normalizeVersion('v1.2.3'), '1.2.3');
    expect(normalizeVersion('1.2.3+7'), '1.2.3');
    expect(normalizeVersion('V2.0.0-beta.1'), '2.0.0');
    expect(normalizeVersion('  0.1.0 '), '0.1.0');
  });

  test('compareVersions orders numerically', () {
    expect(compareVersions('0.1.0', '0.1.0'), 0);
    expect(compareVersions('0.2.0', '0.1.9'), greaterThan(0));
    expect(compareVersions('0.1.10', '0.1.9'), greaterThan(0));
    expect(compareVersions('1.0', '1.0.0'), 0);
    expect(compareVersions('v1.0.1', '1.0.0+5'), greaterThan(0));
    expect(compareVersions('0.9.9', '1.0.0'), lessThan(0));
    expect(compareVersions('abc', '0.0.1'), lessThan(0));
  });

  test('UpdateCheckResult reads the GitHub payload', () {
    final newer = UpdateCheckResult.fromJson({
      'tag_name': 'v0.2.0',
      'html_url': 'https://github.com/pepitolas13/PepoConnect/releases/tag/v0.2.0',
    }, current: '0.1.0');
    expect(newer.isNewer, isTrue);
    expect(newer.latest, '0.2.0');
    expect(newer.url, endsWith('/tag/v0.2.0'));

    final same = UpdateCheckResult.fromJson({'tag_name': '0.1.0'}, current: '0.1.0+1');
    expect(same.isNewer, isFalse);
    expect(same.url, releasesPageUrl);
  });

  test('rejects invalid, prerelease and draft release metadata', () {
    for (final payload in <Map<String, dynamic>>[
      {},
      {'tag_name': 'latest'},
      {'tag_name': 'v9.0.0-beta.1'},
      {'tag_name': 'v9.0.0', 'draft': true},
      {'tag_name': 'v9.0.0', 'prerelease': true},
      {'tag_name': 'v9.0.0', 'html_url': 'https://example.com/install'},
      {'tag_name': 'v9.0.0', 'html_url': '$repositoryUrl/releases/tag/v8.0.0'},
    ]) {
      expect(() => UpdateCheckResult.fromJson(payload, current: '0.3.0'), throwsFormatException);
    }
  });

  test('release assets survive caching and are tied to the release and repository', () {
    const name = 'PepoConnect-win-x64.exe';
    final payload = <String, dynamic>{
      'tag_name': 'v0.4.0',
      'html_url': '$repositoryUrl/releases/tag/v0.4.0',
      'assets': [
        {
          'name': name,
          'browser_download_url': '$repositoryUrl/releases/download/v0.4.0/$name',
          'size': 1234,
          'state': 'uploaded',
        },
      ],
    };
    final release = UpdateCheckResult.fromJson(payload, current: '0.3.0');
    expect(release.assetNamed(name)?.size, 1234);
    final cached = UpdateCheckResult.fromJson(release.toJson(), current: '0.4.0');
    expect(cached.isNewer, isFalse);
    expect(cached.assetNamed(name)?.url, '$repositoryUrl/releases/download/v0.4.0/$name');

    for (final url in [
      'http://github.com/pepitolas13/PepoConnect/releases/download/v0.4.0/$name',
      'https://github.com/another/repo/releases/download/v0.4.0/$name',
      '$repositoryUrl/releases/download/v0.3.0/$name',
      '$repositoryUrl/releases/download/v0.4.0/other.exe',
    ]) {
      final bad = {
        ...payload,
        'assets': [
          {'name': name, 'browser_download_url': url, 'size': 1234},
        ],
      };
      expect(() => UpdateCheckResult.fromJson(bad, current: '0.3.0'), throwsFormatException);
    }
  });

  test('rejects duplicate assets and invalid sizes', () {
    final asset = {
      'name': 'PepoConnect-win-x64.exe',
      'browser_download_url': '$repositoryUrl/releases/download/v0.4.0/PepoConnect-win-x64.exe',
      'size': 1234,
    };
    for (final assets in [
      [asset, asset],
      [
        {...asset, 'size': -1},
      ],
      [
        {...asset, 'size': 0},
      ],
      [
        {...asset, 'name': '../escape.exe'},
      ],
    ]) {
      expect(
        () =>
            UpdateCheckResult.fromJson({'tag_name': 'v0.4.0', 'assets': assets}, current: '0.3.0'),
        throwsFormatException,
      );
    }
  });
}
