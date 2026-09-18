import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pepo_core/pepo_core.dart' show TransferRecord;

import '../../app/app_services.dart';
import '../../platform/open_helper.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/motion.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/motion/toast.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/pill_tabs.dart';
import '../../state/app_settings.dart';
import '../../state/engine_providers.dart';
import '../gallery/thumbnail_lookup.dart';
import 'send_files.dart';
import 'send_to_pc_sheet.dart';
import 'transfer_rows.dart';

/// Phone layout: received / sent lists and the "Send to PC" button.
class TransfersMobile extends ConsumerStatefulWidget {
  const TransfersMobile({super.key});

  @override
  ConsumerState<TransfersMobile> createState() => _TransfersMobileState();
}

class _TransfersMobileState extends ConsumerState<TransfersMobile> {
  /// 0 = received, 1 = sent.
  int _tab = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _consumePending();
    });
  }

  /// Files handed over by another app that still need a destination.
  void _consumePending() {
    final paths = ref.read(pendingShareProvider);
    if (paths.isEmpty || _busy) return;
    unawaited(_sendPending(paths));
  }

  Future<void> _sendPending(List<String> paths) async {
    _busy = true;
    try {
      final target = await _chooseTarget(useDefault: false);
      ref.read(pendingShareProvider.notifier).clear();
      if (target == null || !mounted) return;
      await sendFilesTo(context, ref, deviceId: target, paths: paths);
    } finally {
      _busy = false;
    }
  }

  /// The PC to send to: the default hub when connected, the only connected
  /// one, or whichever the user picks from the sheet.
  Future<String?> _chooseTarget({bool useDefault = true}) async {
    final devices = ref.read(devicesProvider);
    final pcs = devices.where((d) => !d.device.platform.isMobile).toList();
    final candidates = pcs.isEmpty ? devices : pcs;
    final connected = candidates.where((d) => d.connected).toList();
    if (useDefault) {
      final defaultId = ref.read(settingsProvider).defaultHubId;
      if (defaultId != null && connected.any((d) => d.deviceId == defaultId)) return defaultId;
    }
    if (connected.length == 1) return connected.single.deviceId;
    if (connected.isEmpty) {
      ref.read(toastServiceProvider).show(ToastData(title: context.t.trNoPcConnected));
      return null;
    }
    return showChoosePcSheet(context, devices: candidates);
  }

  Future<void> _onSendPressed() async {
    if (_busy) return;
    _busy = true;
    try {
      final source = await showSendToPcSheet(context);
      if (source == null || !mounted) return;
      final picked = await FilePicker.pickFiles(
        type: source == SendSource.gallery ? FileType.media : FileType.any,
        dialogTitle: context.t.mobileSendToPc,
      );
      final paths = [
        for (final f in picked)
          if (f.path != null) f.path!,
      ];
      if (paths.isEmpty || !mounted) return;
      final target = await _chooseTarget();
      if (target == null || !mounted) return;
      await sendFilesTo(context, ref, deviceId: target, paths: paths);
    } finally {
      _busy = false;
    }
  }

  String? _pathOf(TransferRecord r) => r.isIncoming ? r.finalPath : r.sourcePath;

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingShareProvider, (_, next) {
      if (next.isNotEmpty) _consumePending();
    });
    final t = context.t;
    final devices = ref.watch(devicesProvider);
    final transfers = ref.watch(transfersProvider);
    final lookup = ref.watch(thumbnailLookupProvider);
    final notifier = ref.read(transfersProvider.notifier);
    final incoming = _tab == 0;
    final active = transfers.active.where((r) => r.isIncoming == incoming).toList().reversed;
    final history = transfers.history.where((r) => r.isIncoming == incoming).toList();
    final empty = active.isEmpty && history.isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.s),
            child: Center(
              child: PillTabs(
                tabs: [t.mobileReceived, t.mobileSent],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
          ),
          Expanded(
            child: empty
                ? EmptyState(
                    icon: incoming
                        ? FluentIcons.arrow_download_24_regular
                        : FluentIcons.arrow_upload_24_regular,
                    title: incoming ? t.mobileReceivedEmpty : t.mobileSentEmpty,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(Space.s, 0, Space.s, 96),
                    children: [
                      for (final r in active)
                        Padding(
                          key: ValueKey('active-${r.id}'),
                          padding: const EdgeInsets.symmetric(horizontal: Space.s),
                          child: ActiveTransferRow(
                            record: r,
                            deviceName: deviceLabel(devices, r.deviceId),
                            thumbnail: r.sourceId == null ? null : lookup(r.deviceId, r.sourceId!),
                            onPause: () => notifier.pause(r.id),
                            onResume: () => notifier.resume(r.id),
                            onCancel: () => notifier.cancel(r.id),
                          ),
                        ),
                      for (final r in history)
                        HistoryTransferRow(
                          key: ValueKey('history-${r.id}'),
                          record: r,
                          deviceName: deviceLabel(devices, r.deviceId),
                          showDevice: devices.length > 1,
                          thumbnail: r.sourceId == null ? null : lookup(r.deviceId, r.sourceId!),
                          onTap: _pathOf(r) == null ? null : () => OpenHelper.openFile(_pathOf(r)!),
                          onRemove: () => notifier.removeFromHistory(r.id),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: _SendFab(onPressed: _onSendPressed),
    );
  }
}

/// Round accent button with the paper plane: "Send to PC".
class _SendFab extends StatelessWidget {
  const _SendFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    return Pressable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(28),
      showHoverFill: false,
      showPressedOverlay: false,
      semanticLabel: context.t.mobileSendToPc,
      builder: (context, states, _) => AnimatedContainer(
        duration: motion.fast,
        curve: Motion.standard,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: states.pressed
              ? colors.accentPressed
              : states.hovered
              ? colors.accentHover
              : colors.accent,
          shape: BoxShape.circle,
          boxShadow: PepoShadows.flyout,
        ),
        child: Icon(FluentIcons.send_24_filled, size: 24, color: colors.onAccent),
      ),
    );
  }
}
