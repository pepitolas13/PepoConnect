import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../shared/i18n/l10n.dart';
import '../../../shared/theme/tokens.dart';
import '../../../shared/widgets/device_icon.dart';
import '../../../shared/widgets/fluent_button.dart';
import '../../../shared/widgets/pepo_card.dart';
import '../../../state/app_settings.dart';
import '../settings_providers.dart';
import '../settings_widgets.dart';

/// "My PC" card: silhouette, the name announced on the network with the
/// system name under it, and a rename button.
class MyPcSection extends ConsumerWidget {
  const MyPcSection({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, String current) async {
    final t = context.t;
    final value = await showRenameDialog(
      context,
      title: isDesktop ? t.editPcName : t.changeName,
      initial: current,
      placeholder: isDesktop ? t.pcNamePlaceholder : t.deviceNamePlaceholder,
    );
    if (value == null || value == current) return;
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(deviceName: value));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    final settings = ref.watch(settingsProvider);
    final facts = ref.watch(localDeviceFactsProvider);
    final name = settings.deviceName ?? facts.deviceName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s),
          child: Text(isDesktop ? t.myPc : t.setThisPhone, style: text.bodyStrong),
        ),
        PepoCard(
          child: Row(
            children: [
              DeviceIcon(kind: isDesktop ? DeviceKind.desktop : DeviceKind.phone, size: 32),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: text.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      facts.systemName,
                      style: text.caption.copyWith(color: colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.l),
              FluentButton(
                icon: FluentIcons.edit_16_regular,
                label: t.changeName,
                onPressed: () => _rename(context, ref, name),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
