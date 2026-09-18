import 'package:pepo_core/pepo_core.dart';
import 'package:test/test.dart';

void main() {
  test('protocol version is 1', () {
    expect(protocolVersion, 1);
  });
}
