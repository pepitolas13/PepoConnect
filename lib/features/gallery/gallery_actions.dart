import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart' show NameSanitizer, TransferChangedEvent, TransferState;

import '../../app/app_services.dart';
import '../../platform/open_helper.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/toast.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/flyout.dart';
import '../../shared/widgets/pepo_dialog.dart';
import '../../state/engine_providers.dart';

/// Downloads [entry] unless a copy already exists and completes with the
/// local path (null when the transfer failed, was cancelled or timed out).
Future<String?> ensureDownloaded(
  WidgetRef ref,
  GalleryNotifier notifier,
  GalleryEntry entry, {
  Duration timeout = const Duration(minutes: 30),
}) async {
  final local = entry.localPath;
  if (local != null && entry.isDownloaded && File(local).existsSync()) return local;
  final engine = ref.read(engineProvider);
  final completer = Completer<String?>();
  final sub = engine.events.listen((e) {
    if (e is! TransferChangedEvent || completer.isCompleted) return;
    final r = e.record;
    if (r.isIncoming &&
        r.deviceId == entry.deviceId &&
        r.sourceId == entry.id &&
        r.state.isTerminal) {
      completer.complete(r.state == TransferState.done ? r.finalPath : null);
    }
  });
  try {
    await notifier.download([entry]);
    return await completer.future.timeout(timeout, onTimeout: () => null);
  } catch (_) {
    return null;
  } finally {
    await sub.cancel();
  }
}

/// The actions shared by the gallery grid, its context menu and the viewer.
class GalleryActions {
  GalleryActions({required this.context, required this.ref, required this.notifier});

  final BuildContext context;
  final WidgetRef ref;
  final GalleryNotifier notifier;

  ToastService get _toasts => ref.read(toastServiceProvider);

  /// Asks the device for the originals of the entries not on the PC yet.
  Future<void> download(List<GalleryEntry> entries) async {
    final t = context.t;
    final pending = entries.where((e) => !e.isDownloaded).toList();
    if (pending.isEmpty) return;
    try {
      await notifier.download(pending);
      _toasts.show(ToastData(title: t.galDownloadStarted(pending.length)));
    } catch (e) {
      _toasts.show(
        ToastData(
          title: t.galDownloadFailed(pending.first.item.name),
          message: '$e',
          severity: ToastSeverity.critical,
        ),
      );
    }
  }

  /// Copies the entries into a folder chosen by the user, downloading first
  /// whatever is not on the PC.
  Future<void> saveAs(List<GalleryEntry> entries) async {
    if (entries.isEmpty) return;
    final t = context.t;
    final dir = await FilePicker.getDirectoryPath(dialogTitle: t.saveAs);
    if (dir == null) return;
    var saved = 0;
    String? failed;
    for (final e in entries) {
      final source = await ensureDownloaded(ref, notifier, e);
      if (source == null) {
        failed ??= e.item.name;
        continue;
      }
      try {
        final target = NameSanitizer.uniquePath(dir, p.basename(source));
        await File(source).copy(target);
        saved++;
      } catch (_) {
        failed ??= e.item.name;
      }
    }
    if (saved > 0) {
      _toasts.show(
        ToastData(
          title: t.galSavedCopies(saved, dir),
          severity: ToastSeverity.success,
          actions: [ToastAction(label: t.openFolder, onPressed: () => OpenHelper.openFolder(dir))],
        ),
      );
    }
    if (failed != null) {
      _toasts.show(ToastData(title: t.galSaveFailed(failed), severity: ToastSeverity.critical));
    }
  }

  /// Confirms, then deletes on the device. Returns true when something was
  /// deleted.
  Future<bool> deleteOnDevice(List<GalleryEntry> entries) async {
    if (entries.isEmpty) return false;
    final t = context.t;
    final confirmed = await showPepoDialog<bool>(
      context,
      builder: (dialog) => PepoDialog(
        title: t.deleteFromPhoneConfirm(entries.length),
        content: Text(t.deleteFromPhoneBody),
        actions: [
          FluentButton(label: t.cancel, onPressed: () => Navigator.of(dialog).pop(false)),
          FluentButton.primary(label: t.delete, onPressed: () => Navigator.of(dialog).pop(true)),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      final deleted = await notifier.deleteOnDevice(entries);
      if (deleted.isNotEmpty) _toasts.show(ToastData(title: t.toastDeleted(deleted.length)));
      return deleted.isNotEmpty;
    } catch (e) {
      _toasts.show(
        ToastData(title: t.galDeleteFailed, message: '$e', severity: ToastSeverity.critical),
      );
      return false;
    }
  }

  /// Opens the local copy with the system handler.
  Future<void> open(GalleryEntry e) async {
    final path = e.localPath;
    if (path != null && e.isDownloaded) await OpenHelper.openFile(path);
  }

  Future<void> showInFolder(GalleryEntry e) async {
    final path = e.localPath;
    if (path != null && e.isDownloaded) await OpenHelper.showInFolder(path);
  }

  /// Clears the "new" mark.
  Future<void> dismiss(List<GalleryEntry> entries) async {
    for (final e in entries.where((e) => e.isNew)) {
      await notifier.dismiss(e);
    }
  }

  /// Context menu / "more" entries for [entries]. [onOpenViewer] opens the
  /// viewer for a single entry that is not on the PC yet.
  List<MenuEntry> menuItems(List<GalleryEntry> entries, {VoidCallback? onOpenViewer}) {
    final t = context.t;
    if (entries.isEmpty) return const [];
    final single = entries.length == 1 ? entries.first : null;
    final onPc = entries.where((e) => e.isDownloaded && e.localPath != null).toList();
    final items = <MenuEntry>[
      if (single != null)
        MenuItem(
          label: t.open,
          icon: FluentIcons.open_16_regular,
          onTap: () {
            if (single.isDownloaded && single.localPath != null) {
              open(single);
            } else {
              onOpenViewer?.call();
            }
          },
        ),
      MenuItem(
        label: t.download,
        icon: FluentIcons.arrow_download_16_regular,
        enabled: entries.any((e) => !e.isDownloaded),
        onTap: () => download(entries),
      ),
      MenuItem(
        label: t.saveAs,
        icon: FluentIcons.folder_arrow_right_16_regular,
        onTap: () => saveAs(entries),
      ),
      const MenuDivider(),
      if (onPc.isNotEmpty)
        MenuItem(
          label: t.showInFolder,
          icon: FluentIcons.folder_16_regular,
          onTap: () => showInFolder(onPc.first),
        ),
      if (entries.any((e) => e.isNew))
        MenuItem(
          label: t.dismiss,
          icon: FluentIcons.eye_off_16_regular,
          onTap: () => dismiss(entries),
        ),
      const MenuDivider(),
      MenuItem(
        label: t.deleteFromPhone,
        icon: FluentIcons.delete_16_regular,
        destructive: true,
        onTap: () => deleteOnDevice(entries),
      ),
    ];
    return _tidy(items);
  }

  /// Removes leading, trailing and doubled dividers.
  static List<MenuEntry> _tidy(List<MenuEntry> items) {
    final out = <MenuEntry>[];
    for (final item in items) {
      if (item is MenuDivider && (out.isEmpty || out.last is MenuDivider)) continue;
      out.add(item);
    }
    while (out.isNotEmpty && out.last is MenuDivider) {
      out.removeLast();
    }
    return out;
  }
}
