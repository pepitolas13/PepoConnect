import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pepo_core/pepo_core.dart' show TransferRecord;

import '../../app/router.dart';
import '../../platform/open_helper.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/device_icon.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/pill_tabs.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/engine_providers.dart';
import '../gallery/thumbnail_lookup.dart';
import 'device_drop_zone.dart';
import 'send_files.dart';
import 'transfer_rows.dart';

/// "Historial · 12" with the received / sent pills and "Clear history"; the
/// title gives way so the controls never overflow.
class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.title,
    required this.count,
    required this.tabs,
    required this.onClear,
  });

  final String title;
  final int? count;
  final Widget tabs;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, Space.l, 0, Space.s),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: text.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count != null) ...[
                  Text('  ·  ', style: text.body.copyWith(color: colors.textTertiary)),
                  Text('$count', style: text.body.copyWith(color: colors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          tabs,
          if (onClear != null) ...[
            const SizedBox(width: Space.s),
            FluentButton.subtle(
              label: context.t.clearHistory,
              size: FluentButtonSize.small,
              onPressed: onClear,
            ),
          ],
        ],
      ),
    );
  }
}

/// Desktop transfers: one drop zone per paired device, "in progress" and the
/// history (received / sent).
class TransfersDesktop extends ConsumerStatefulWidget {
  const TransfersDesktop({super.key, required this.onShareWithAnyone});

  final VoidCallback onShareWithAnyone;

  static const double contentWidth = 720;

  @override
  ConsumerState<TransfersDesktop> createState() => _TransfersDesktopState();
}

class _TransfersDesktopState extends ConsumerState<TransfersDesktop> {
  /// 0 = received, 1 = sent.
  int _historyTab = 0;

  Future<void> _pickFor(String deviceId) async {
    final picked = await FilePicker.pickFiles(dialogTitle: context.t.addFiles);
    if (!mounted) return;
    final paths = [
      for (final f in picked)
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty) return;
    await sendFilesTo(context, ref, deviceId: deviceId, paths: paths);
  }

  String? _pathOf(TransferRecord r) => r.isIncoming ? r.finalPath : r.sourcePath;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final devices = ref.watch(devicesProvider);
    final transfers = ref.watch(transfersProvider);
    final lookup = ref.watch(thumbnailLookupProvider);
    final notifier = ref.read(transfersProvider.notifier);
    final active = transfers.active;
    final history = transfers.history
        .where((r) => _historyTab == 0 ? r.isIncoming : !r.isIncoming)
        .toList();

    Widget section(List<Widget> children) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TransfersDesktop.contentWidth),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
        children: [
          PageTitle(title: t.transfersTitle, subtitle: t.transfersSubtitle),
          if (devices.isEmpty)
            EmptyState(
              icon: FluentIcons.phone_desktop_24_regular,
              title: t.noDevicesYet,
              message: t.pairFirstDevice,
              actionLabel: t.addDevice,
              onAction: () => context.go(AppRoutes.pair),
            )
          else
            Center(
              child: Wrap(
                spacing: Space.l,
                runSpacing: Space.l,
                alignment: WrapAlignment.center,
                children: [
                  for (final d in devices)
                    DeviceDropZone(
                      key: ValueKey('zone-${d.deviceId}'),
                      name: d.device.name,
                      kind: DeviceKind.fromPlatform(d.device.platform, model: d.device.model),
                      connected: d.connected,
                      onFiles: (paths) =>
                          sendFilesTo(context, ref, deviceId: d.deviceId, paths: paths),
                      onAddFiles: () => _pickFor(d.deviceId),
                    ),
                ],
              ),
            ),
          const SizedBox(height: Space.l),
          Center(
            child: FluentButton.subtle(
              icon: FluentIcons.link_16_regular,
              label: t.trShareWithAnyone,
              onPressed: widget.onShareWithAnyone,
            ),
          ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: Space.l),
            section([
              SectionHeader(title: t.transfersInProgress, count: active.length),
              for (final r in active)
                ActiveTransferRow(
                  key: ValueKey('active-${r.id}'),
                  record: r,
                  deviceName: deviceLabel(devices, r.deviceId),
                  thumbnail: r.sourceId == null ? null : lookup(r.deviceId, r.sourceId!),
                  onPause: () => notifier.pause(r.id),
                  onCancel: () => notifier.cancel(r.id),
                ),
            ]),
          ],
          const SizedBox(height: Space.s),
          section([
            _HistoryHeader(
              title: t.trHistory,
              count: history.isEmpty ? null : history.length,
              tabs: PillTabs(
                tabs: [t.mobileReceived, t.mobileSent],
                index: _historyTab,
                onChanged: (i) => setState(() => _historyTab = i),
              ),
              onClear: transfers.history.isEmpty ? null : notifier.clearHistory,
            ),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.m),
                child: Text(
                  t.transfersEmptyBody,
                  style: text.caption.copyWith(color: colors.textSecondary),
                ),
              )
            else
              for (final r in history)
                HistoryTransferRow(
                  key: ValueKey('history-${r.id}'),
                  record: r,
                  deviceName: deviceLabel(devices, r.deviceId),
                  thumbnail: r.sourceId == null ? null : lookup(r.deviceId, r.sourceId!),
                  onOpen: _pathOf(r) == null ? null : () => OpenHelper.openFile(_pathOf(r)!),
                  onShowInFolder: _pathOf(r) == null
                      ? null
                      : () => OpenHelper.showInFolder(_pathOf(r)!),
                  onRemove: () => notifier.removeFromHistory(r.id),
                ),
          ]),
        ],
      ),
    );
  }
}
