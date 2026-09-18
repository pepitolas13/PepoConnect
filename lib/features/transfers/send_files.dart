import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/app_services.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/toast.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/pepo_dialog.dart';
import '../../state/app_settings.dart';
import '../../state/engine_providers.dart';

const _executableExtensions = [
  '.exe',
  '.msi',
  '.bat',
  '.cmd',
  '.com',
  '.scr',
  '.ps1',
  '.vbs',
  '.js',
  '.jar',
  '.apk',
];

/// Files Unison refused outright; we warn unless the setting allows them.
bool isExecutableName(String name) {
  final lower = name.toLowerCase();
  return _executableExtensions.any(lower.endsWith);
}

/// Queues [paths] for [deviceId], asking first when an executable is among
/// them and the setting does not allow them. Errors surface as a toast.
Future<void> sendFilesTo(
  BuildContext context,
  WidgetRef ref, {
  required String deviceId,
  required List<String> paths,
}) async {
  if (paths.isEmpty) return;
  final t = context.t;
  if (!ref.read(settingsProvider).allowExecutables) {
    final executables = paths.map(p.basename).where(isExecutableName).toList();
    if (executables.isNotEmpty) {
      final proceed = await showPepoDialog<bool>(
        context,
        builder: (dialog) => PepoDialog(
          title: t.executableWarning(executables.first),
          content: Text(t.executableBlocked),
          actions: [
            FluentButton(label: t.cancel, onPressed: () => Navigator.of(dialog).pop(false)),
            FluentButton.primary(
              label: t.trExecutableSendAnyway,
              onPressed: () => Navigator.of(dialog).pop(true),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
  }
  try {
    await ref.read(transfersProvider.notifier).send(deviceId, paths);
  } catch (e) {
    ref
        .read(toastServiceProvider)
        .show(ToastData(title: t.trSendFailed, message: '$e', severity: ToastSeverity.critical));
  }
}
