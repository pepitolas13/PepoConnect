import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pepo_core/src/share/guest_share_server.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late GuestShareServer server;
  final client = HttpClient();

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pepo_guest_');
    server = GuestShareServer(
      hostName: 'PC de Daniel',
      receiveDir: p.join(tmp.path, 'Invitados'),
      port: 0,
    );
  });

  tearDown(() async {
    await server.dispose();
    await tmp.delete(recursive: true);
  });

  Future<HttpClientResponse> get(String url, {Map<String, String> headers = const {}}) async {
    final req = await client.getUrl(Uri.parse(url));
    headers.forEach(req.headers.set);
    return req.close();
  }

  test('send session: page lists files, downloads with ranges, single client', () async {
    final f = File(p.join(tmp.path, 'foto ñ.jpg'))
      ..writeAsBytesSync(List.generate(5000, (i) => i & 0xFF));
    final events = <GuestEventKind>[];
    server.events.listen((e) => events.add(e.kind));
    final s = await server.startSend([f.path], message: 'Hola');
    final url = s.urls(['127.0.0.1'], server.boundPort).single;
    expect(url, startsWith('http://127.0.0.1:'));

    final page = await get(url);
    expect(page.statusCode, 200);
    final html = await utf8.decodeStream(page);
    expect(html, contains('"name":"foto ñ.jpg"'));
    expect(html, contains('"message":"Hola"'));
    expect(s.boundRemote, '127.0.0.1');

    final dl = await get('$url/file/f0');
    expect(dl.statusCode, 200);
    expect(dl.headers.value('content-disposition'), contains('filename*=UTF-8'));
    final bytes = await dl.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(bytes, f.readAsBytesSync());

    final part = await get('$url/file/f0', headers: {'Range': 'bytes=100-199'});
    expect(part.statusCode, 206);
    expect(part.headers.value('content-range'), 'bytes 100-199/5000');
    expect((await part.fold<List<int>>([], (a, b) => a..addAll(b))).length, 100);

    final missing = await get('$url/file/nope');
    expect(missing.statusCode, 404);
    final wrongToken = await get('${url}x');
    expect(wrongToken.statusCode, 410);
    expect(
      events,
      containsAllInOrder([
        GuestEventKind.created,
        GuestEventKind.opened,
        GuestEventKind.downloaded,
      ]),
    );
    expect(s.downloads, 1);

    server.cancel();
    final gone = await get(url);
    expect(gone.statusCode, 410);
  });

  test('receive session: uploads land in the guests folder with safe names', () async {
    final s = await server.startReceive(message: 'Mándame las fotos');
    final url = s.urls(['127.0.0.1'], server.boundPort).single;
    final page = await get(url);
    expect(page.statusCode, 200);
    expect(await utf8.decodeStream(page), contains('"mode":"receive"'));

    Future<int> upload(String name, List<int> data) async {
      final req = await client.putUrl(Uri.parse('$url/upload?name=${Uri.encodeComponent(name)}'));
      req.contentLength = data.length;
      req.add(data);
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode;
    }

    expect(await upload('../../evil.txt', utf8.encode('x')), 200);
    expect(await upload('evil.txt', utf8.encode('y')), 200);
    final files = Directory(server.receiveDir).listSync().map((e) => p.basename(e.path)).toList()
      ..sort();
    expect(files, ['evil (2).txt', 'evil.txt']);
    expect(File(p.join(server.receiveDir, 'evil.txt')).readAsStringSync(), 'x');
    expect(s.uploads, 2);

    // Uploads are refused on a send session and after expiry.
    final send = await server.startSend([]);
    final res = await get('${send.urls(['127.0.0.1'], server.boundPort).single}/upload');
    expect(res.statusCode, 404);
  });

  test('sessions expire', () async {
    final short = GuestShareServer(
      hostName: 'PC',
      receiveDir: tmp.path,
      port: 0,
      ttl: const Duration(milliseconds: 300),
    );
    addTearDown(short.dispose);
    final expired = short.events.firstWhere((e) => e.kind == GuestEventKind.expired);
    final s = await short.startReceive();
    await expired.timeout(const Duration(seconds: 3));
    expect(s.isExpired, isTrue);
    expect(short.session, isNull);
  });
}
