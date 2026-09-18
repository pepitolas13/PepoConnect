import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/features/transfers/device_drop_zone.dart';
import 'package:pepoconnect/features/transfers/file_type_icon.dart';
import 'package:pepoconnect/features/transfers/send_files.dart';
import 'package:pepoconnect/features/transfers/transfers_page.dart';
import 'package:pepoconnect/shared/widgets/empty_state.dart';
import 'package:pepoconnect/shared/widgets/pill_tabs.dart';
import 'package:pepoconnect/state/engine_providers.dart';

import '../gallery/fakes.dart';

void main() {
  testWidgets('desktop shows one drop zone per paired device', (tester) async {
    await pumpFeature(
      tester,
      child: const TransfersPage(),
      overrides: featureOverrides(devices: sampleDevices()),
    );
    expect(find.byType(DeviceDropZone), findsNWidgets(3));
    expect(find.text('Pixel 8'), findsOneWidget);
    expect(find.text('iPad de Daniel'), findsOneWidget);
    expect(find.text('GeorGY'), findsOneWidget);
    expect(find.text('Transferir archivos'), findsOneWidget);
    // Only the connected device offers "Add files…"; the others say offline.
    expect(find.text('Añadir archivos…'), findsOneWidget);
    expect(find.text('Sin conexión'), findsNWidgets(2));
    expect(find.text('Compartir con cualquiera'), findsOneWidget);
  }, variant: desktopVariant);

  testWidgets('desktop without devices shows the empty state', (tester) async {
    await pumpFeature(
      tester,
      child: const TransfersPage(),
      overrides: featureOverrides(devices: const []),
    );
    expect(find.byType(DeviceDropZone), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Añadir dispositivo'), findsOneWidget);
  }, variant: desktopVariant);

  testWidgets('desktop lists active transfers and the history', (tester) async {
    final done = fakeTransfer(
      id: 7,
      deviceId: 'pixel8',
      name: 'IMG_0142.jpg',
      direction: TransferDirection.receive,
      state: TransferState.done,
      bytesDone: 12 * 1024 * 1024,
    )..finishedAt = DateTime.now();
    await pumpFeature(
      tester,
      child: const TransfersPage(),
      overrides: featureOverrides(
        devices: sampleDevices(),
        transfers: TransfersState(
          active: [
            fakeTransfer(id: 1, deviceId: 'pixel8', name: 'video.mp4', bytesDone: 4 * 1024 * 1024),
          ],
          history: [done],
        ),
      ),
    );
    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('video.mp4'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('IMG_0142.jpg'), findsOneWidget);
    expect(find.text('Borrar historial'), findsOneWidget);
  }, variant: desktopVariant);

  testWidgets('phone width shows received / sent tabs and the send button', (tester) async {
    final sent = TransferRecord(
      id: 3,
      deviceId: fakeDeviceId('georgy'),
      direction: TransferDirection.send,
      name: 'informe.docx',
      size: 2 * 1024 * 1024,
      mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      state: TransferState.done,
      bytesDone: 2 * 1024 * 1024,
    )..finishedAt = DateTime.now();
    await pumpFeature(
      tester,
      child: const TransfersPage(),
      overrides: featureOverrides(
        devices: sampleDevices(),
        transfers: TransfersState(history: [sent]),
      ),
      size: const Size(400, 800),
    );
    expect(find.byType(DeviceDropZone), findsNothing);
    expect(find.byType(PillTabs), findsOneWidget);
    expect(find.text('Recibidos'), findsOneWidget);
    expect(find.text('Enviados'), findsOneWidget);
    expect(find.byIcon(FluentIcons.send_24_filled), findsOneWidget);
    // Nothing received yet.
    expect(find.text('Los archivos que te envíe el PC aparecerán aquí'), findsOneWidget);

    await tester.tap(find.text('Enviados'));
    await tester.pumpAndSettle();
    expect(find.text('informe.docx'), findsOneWidget);
    expect(find.text('DOCX'), findsOneWidget);
  }, variant: touchVariant);

  test('file families and extension labels', () {
    expect(fileFamilyOf('foto.jpg'), FileFamily.image);
    expect(fileFamilyOf('clip.mov', 'video/quicktime'), FileFamily.video);
    expect(fileFamilyOf('informe.docx'), FileFamily.document);
    expect(fileFamilyOf('archivo.zip'), FileFamily.archive);
    expect(fileExtensionLabel('hoja.xlsx'), 'XLSX');
    expect(fileExtensionLabel('notas.markdown'), 'MARK');
    expect(fileExtensionLabel('sin_extension'), '');
  });

  test('executables are recognised by extension', () {
    expect(isExecutableName('setup.exe'), isTrue);
    expect(isExecutableName('Script.PS1'), isTrue);
    expect(isExecutableName('foto.jpg'), isFalse);
  });
}
