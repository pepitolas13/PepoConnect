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
}
