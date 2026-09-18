import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:pepo_core/pepo_core.dart' show DeviceView;

import '../../shared/i18n/l10n.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/device_icon.dart';
import '../../shared/widgets/status_pill.dart';

/// What a "Send to PC" sends: picked files, gallery items or the clipboard.
enum SendSource { files, gallery, clipboard }

/// Bottom sheet "Send to PC: Files / Gallery / Clipboard / Cancel".
Future<SendSource?> showSendToPcSheet(BuildContext context) {
  final t = context.t;
  return _showSheet<SendSource>(
    context,
    title: t.mobileSendToPc,
    rows: (sheet) => [
      _SheetRow(
        icon: FluentIcons.document_20_regular,
        label: t.mobileFiles,
        onTap: () => Navigator.of(sheet).pop(SendSource.files),
      ),
      _SheetRow(
        icon: FluentIcons.image_multiple_20_regular,
        label: t.mobileGallery,
        onTap: () => Navigator.of(sheet).pop(SendSource.gallery),
      ),
      _SheetRow(
        icon: FluentIcons.clipboard_paste_20_regular,
        label: t.mobileClipboard,
        onTap: () => Navigator.of(sheet).pop(SendSource.clipboard),
      ),
    ],
  );
}

/// Bottom sheet listing the paired PCs; returns the chosen device id.
Future<String?> showChoosePcSheet(BuildContext context, {required List<DeviceView> devices}) {
  final t = context.t;
  return _showSheet<String>(
    context,
    title: t.chooseDevice,
    rows: (sheet) => [
      for (final d in devices)
        _SheetRow(
          leading: DeviceIcon.fromPlatform(d.device.platform, model: d.device.model, size: 24),
          label: d.device.name,
          trailing: StatusPill(
            status: d.connected
                ? ConnectionStatus.connected
                : d.connecting
                ? ConnectionStatus.connecting
                : ConnectionStatus.offline,
            label: d.connected
                ? t.statusConnected
                : d.connecting
                ? t.statusConnecting
                : t.statusOffline,
          ),
          enabled: d.connected,
          onTap: () => Navigator.of(sheet).pop(d.deviceId),
        ),
    ],
  );
}

Future<T?> _showSheet<T>(
  BuildContext context, {
  required String title,
  required List<Widget> Function(BuildContext sheet) rows,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.pepo.isDark ? const Color(0x99000000) : const Color(0x4D000000),
    builder: (sheet) => _SheetSurface(
      title: title,
      children: [
        ...rows(sheet),
        Divider(height: 1, color: sheet.pepo.divider),
        _SheetRow(
          icon: FluentIcons.dismiss_20_regular,
          label: sheet.t.cancel,
          onTap: () => Navigator.of(sheet).pop(),
        ),
      ],
    ),
  );
}

/// Rounded floating surface at the bottom edge (Fluent, not Material).
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.s),
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.flyoutSurface,
              borderRadius: Radii.dropZoneRadius,
              border: Border.all(color: colors.cardStroke),
              boxShadow: PepoShadows.flyout,
            ),
            child: ClipRRect(
              borderRadius: Radii.dropZoneRadius,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.s),
                    child: Text(title, style: text.bodyStrong),
                  ),
                  ...children,
                  const SizedBox(height: Space.xs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.onTap,
    this.icon,
    this.leading,
    this.trailing,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final fg = enabled ? colors.textPrimary : colors.textDisabled;
    return Pressable(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      scaleOnPress: false,
      semanticLabel: label,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          child: Row(
            children: [
              if (leading != null)
                IconTheme.merge(
                  data: IconThemeData(color: fg),
                  child: leading!,
                )
              else if (icon != null)
                Icon(icon, size: 20, color: fg),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text(
                  label,
                  style: context.text.body.copyWith(color: fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
