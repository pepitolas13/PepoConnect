// Dev helper: serves a guest "send" session with sample files and keeps
// running until killed. Usage: dart run tool/serve_guest.dart [receive]
import 'dart:io';

import 'package:pepo_core/src/media/image_ops.dart';
import 'package:pepo_core/src/share/guest_share_server.dart';

Future<void> main(List<String> args) async {
  final tmp = await Directory.systemTemp.createTemp('pepo_guest_demo_');
  final photo = File('${tmp.path}/IMG_20260918_1201.jpg')
    ..writeAsBytesSync(ImageOps.solidJpeg(1600, 1200, r: 30, g: 90, b: 160));
  final doc = File('${tmp.path}/Presupuesto PepoTech 2026.pdf')
    ..writeAsBytesSync(List.filled(48 * 1024, 65));
  final server = GuestShareServer(
    hostName: 'PC de Daniel',
    receiveDir: '${tmp.path}/Invitados',
    port: 47475,
  );
  server.events.listen(
    (e) => stdout.writeln('event: ${e.kind.name} ${e.fileName ?? ''} ${e.remote ?? ''}'),
  );
  final session = args.contains('receive')
      ? await server.startReceive(message: 'Mándame las fotos de la grabación de hoy.')
      : await server.startSend([photo.path, doc.path], message: 'Aquí tienes lo de esta mañana.');
  stdout.writeln('URL: ${session.urls(['127.0.0.1'], server.boundPort).single}');
  stdout.writeln('receiveDir: ${server.receiveDir}');
  await ProcessSignal.sigint.watch().first;
  await server.dispose();
}
