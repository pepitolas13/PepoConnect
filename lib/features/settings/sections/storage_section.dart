import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/open_helper.dart';
import '../../../shared/i18n/l10n.dart';
import '../../../shared/theme/tokens.dart';
import '../../../shared/widgets/fluent_button.dart';
import '../../../shared/widgets/pepo_card.dart';
import '../../../shared/widgets/toggle_switch.dart';
import '../../../state/app_settings.dart';
import '../settings_providers.dart';
import '../settings_widgets.dart';

/// Where received files go, one folder per device, executables.
class StorageSection extends ConsumerWidget {
  const StorageSection({super.key});

  Future<void> _changeLocation(BuildContext context, WidgetRef ref, String current) async {
    final t = context.t;
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: t.setChooseFolder,
      initialDirectory: current,
    );
    if (path == null || path.isEmpty) return;
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(downloadRoot: path));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    final settings = ref.watch(settingsProvider);
    final facts = ref.watch(localDeviceFactsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final root = settings.downloadRoot ?? facts.downloadRoot;
    final isDefault = settings.downloadRoot == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s),
          child: Text(t.setStorage, style: text.bodyStrong),
        ),
        PepoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.downloadsSavedIn, style: text.body),
              const SizedBox(height: Space.s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(FluentIcons.folder_24_regular, size: 24, color: colors.accent),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(root, style: text.bodyStrong, maxLines: 2),
                        if (isDefault)
                          Text(
                            t.setDefaultLocation,
                            style: text.caption.copyWith(color: colors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.l),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  FluentButton(
                    icon: FluentIcons.folder_open_20_regular,
                    label: t.changeLocation,
                    onPressed: () => _changeLocation(context, ref, root),
                  ),
                  FluentButton(
                    icon: FluentIcons.open_16_regular,
                    label: t.openFolder,
                    onPressed: () => OpenHelper.openFolder(root),
                  ),
                  if (!isDefault)
                    FluentButton.subtle(
                      icon: FluentIcons.arrow_reset_20_regular,
                      label: t.setResetLocation,
                      onPressed: () => ref.read(settingsActionsProvider).resetDownloadRoot(),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        SettingsGroup(
          children: [
            SettingsRow(
              title: t.separateByDevice,
              description: t.setSeparateByDeviceBody,
              trailing: ToggleSwitch(
                value: settings.separateByDevice,
                onChanged: (v) => notifier.update((s) => s.copyWith(separateByDevice: v)),
              ),
            ),
            SettingsRow(
              title: t.allowExecutables,
              description: t.setAllowExecutablesBody,
              trailing: ToggleSwitch(
                value: settings.allowExecutables,
                onChanged: (v) => notifier.update((s) => s.copyWith(allowExecutables: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
