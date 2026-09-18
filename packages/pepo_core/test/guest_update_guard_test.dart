import 'dart:io';

import 'package:pepo_core/src/share/guest_share_server.dart';
import 'package:test/test.dart';

void main() {
  test('an accepted guest upload remains active after the invitation is closed', () async {
    final directory = await Directory.systemTemp.createTemp('pepo-update-guest-');
    final server = GuestShareServer(hostName: 'test', receiveDir: directory.path, port: 0);
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.dispose();
      await directory.delete(recursive: true);
    });
    final session = await server.startReceive();
    final started = server.events.firstWhere((_) => server.activeTransfers == 1);
    final request = await client.putUrl(
      Uri.parse('${session.urls(['127.0.0.1'], server.boundPort).single}/upload?name=test.txt'),
    );
    request.bufferOutput = false;
    request.contentLength = 4;
    request.add([1]);
    await request.flush();
    await started.timeout(const Duration(seconds: 5));
    server.cancel();
    expect(server.session, isNull);
    expect(server.activeTransfers, 1);
    final finished = server.events.firstWhere((_) => server.activeTransfers == 0);
    request.add([2, 3, 4]);
    final response = await request.close();
    await response.drain<void>();
    await finished.timeout(const Duration(seconds: 5));
    expect(response.statusCode, HttpStatus.ok);
    expect(server.activeTransfers, 0);
    expect(await File('${directory.path}/test.txt').readAsBytes(), [1, 2, 3, 4]);
  });
}
