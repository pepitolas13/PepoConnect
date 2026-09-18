import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart' show ExecutableNames;

import '../../app/app_services.dart';
import '../../app/router.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/toast.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/pepo_dialog.dart';
import '../../state/app_settings.dart';
import '../../state/engine_providers.dart';

/// [paths] split into what may go now and the programs the setting keeps
/// back. Everything goes once "allow executables" is on (the receiving
/// device still has its own switch).
({List<String> allowed, List<String> blocked}) splitBlockedExecutables(
  WidgetRef ref,
  List<String> paths,
) {
  if (ref.read(settingsProvider).allowExecutables) return (allowed: paths, blocked: const []);
  final allowed = <String>[];
  final blocked = <String>[];
  for (final path in paths) {
    (ExecutableNames.isExecutable(p.basename(path)) ? blocked : allowed).add(path);
  }
  return (allowed: allowed, blocked: blocked);
}

/// Tells the user which programs stayed behind and why, with a shortcut to
/// the setting. Does nothing when [blocked] is empty.
Future<void> explainBlockedExecutables(BuildContext context, List<String> blocked) async {
  if (blocked.isEmpty) return;
  final t = context.t;
  await showPepoDialog<void>(
    context,
    builder: (dialog) => PepoDialog(
      title: blocked.length == 1
          ? t.executableBlockedOne(p.basename(blocked.first))
          : t.executableBlockedMany(blocked.length),
      content: Text(t.executableBlockedBody),
      actions: [
        FluentButton(
          label: t.executableOpenSettings,
          onPressed: () {
            Navigator.of(dialog).pop();
            GoRouter.maybeOf(context)?.go(AppRoutes.settings);
          },
        ),
        FluentButton.primary(label: t.ok, onPressed: () => Navigator.of(dialog).pop()),
      ],
    ),
  );
}

/// Queues [paths] for [deviceId]. Programs stay behind unless the setting
/// allows them, and the user is told once. Errors surface as a toast.
Future<void> sendFilesTo(
  BuildContext context,
  WidgetRef ref, {
  required String deviceId,
  required List<String> paths,
}) async {
  if (paths.isEmpty) return;
  final t = context.t;
  final split = splitBlockedExecutables(ref, paths);
  if (split.allowed.isNotEmpty) {
    try {
      await ref.read(transfersProvider.notifier).send(deviceId, split.allowed);
    } catch (e) {
      ref
          .read(toastServiceProvider)
          .show(ToastData(title: t.trSendFailed, message: '$e', severity: ToastSeverity.critical));
    }
  }
  if (!context.mounted) return;
  await explainBlockedExecutables(context, split.blocked);
}
