import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';

import '../features/transfers/transfer_errors.dart';
import '../l10n/generated/app_localizations.dart';
import '../platform/android_service.dart';
import '../platform/autostart.dart';
import '../platform/clipboard_sync.dart';
import '../platform/desktop_integration.dart';
import '../platform/ios_background.dart';
import '../platform/media_source_photo_manager.dart';
import '../platform/mobile_permissions.dart';
import '../platform/notifications.dart';
import '../platform/open_helper.dart';
import '../platform/pepo_native.dart';
import '../platform/share_intake.dart';
import '../platform/transfer_chime.dart';
import '../shared/motion/toast.dart';
import '../shared/util/format.dart';
import '../state/app_settings.dart';
import '../state/engine_providers.dart';
import 'bootstrap.dart';
import 'router.dart';

/// The in-app toast service (overridden in `main`).
final toastServiceProvider = Provider<ToastService>((ref) => throw UnimplementedError());

/// Files handed over by the share sheet that still need a destination.
class PendingShareNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void set(List<String> paths) => state = paths;

  void clear() => state = const [];
}

final pendingShareProvider = NotifierProvider<PendingShareNotifier, List<String>>(
  PendingShareNotifier.new,
);

/// Glue between the engine, the OS and the UI: system notifications, toasts,
/// clipboard sync, tray badge, Android foreground service, share intake.
class AppServices with WidgetsBindingObserver {
  AppServices(this.ref, this.router);

  final ProviderContainer ref;
  final GoRouter router;
  final List<StreamSubscription<dynamic>> _subs = [];
  ClipboardSync? _clipboard;

  /// New photos arriving in a burst share one toast per device.
  final Map<String, _PhotoBurst> _bursts = {};
  static const _burstWindow = Duration(seconds: 8);

  /// Pairing already announces the device; skip the 'connected' toast that
  /// follows right after (and flapping reconnects).
  final Map<String, DateTime> _connectedToastAt = {};
  ShareIntake? _share;
  ProviderSubscription<AppSettings>? _settingsSub;
  ProviderSubscription<TransfersState>? _transfersSub;
  ProviderSubscription<List<DeviceView>>? _devicesSub;
  AppLocalizations? _l10n;
  Timer? _exportCleanup;
  bool _started = false;

  PepoEngine get engine => ref.read(engineProvider);
  ToastService get toasts => ref.read(toastServiceProvider);
  AppSettings get settings => ref.read(settingsProvider);

  /// Localizations for messages generated outside the widget tree.
  void attachLocalizations(AppLocalizations l10n) {
    if (identical(_l10n, l10n)) return;
    _l10n = l10n;
    if (DesktopIntegration.isSupported) {
      DesktopIntegration.instance.setLabels(
        open: 'Abrir PepoConnect',
        pauseAll: 'Pausar transferencias',
        downloads: l10n.navDownloads,
        quit: 'Salir',
      );
    }
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subs.add(engine.events.listen(_onEvent));
    _settingsSub = ref.listen<AppSettings>(settingsProvider, _onSettings);
    _transfersSub = ref.listen<TransfersState>(transfersProvider, (_, next) {
      if (DesktopIntegration.isSupported) {
        DesktopIntegration.instance.setActiveTransfers(next.activeCount);
      }
      // iOS: hold the process up for as long as something is moving, so a
      // transfer started right before the app left the screen still lands.
      if (IosBackground.isSupported) {
        unawaited(IosBackground.hold(next.active.isNotEmpty));
      }
      if (next.active.isEmpty) _scheduleExportCleanup();
    });
    _devicesSub = ref.listen<List<DeviceView>>(devicesProvider, _onDevices);
    final clip = ref.read(clipboardSyncProvider);
    _clipboard = clip;
    clip.start(poll: isDesktop);
    clip.setEnabled(settings.clipboardSharing, poll: isDesktop);
    engine.setClipboardSharing(settings.clipboardSharing);
    if (ShareIntake.isSupported) {
      _share = ShareIntake(onFiles: _onSharedFiles, onText: _onSharedText);
      await _share!.start();
    }
    if (PepoNative.isSupported) {
      // Quick-settings tile / launcher shortcut hand the clipboard over here.
      PepoNative.onClipboardText = _onNativeClipboard;
      PepoNative.onBackgroundTask = _onBackgroundTask;
      PepoNative.init();
      await PepoNative.markClipboardReady();
      await PepoNative.markBackgroundReady();
    }
    if (Autostart.isSupported) unawaited(Autostart.refresh());
    SystemNotifications.instance.onTap = _onNotificationTap;
    WidgetsBinding.instance.addObserver(this);
    await _applyAutoSend();
    await _updateBackground(ref.read(devicesProvider));
  }

  /// Re-applies the phone's "send every new photo" target from the setting.
  ///
  /// The engine keeps it in memory only, so without this the switch reads on
  /// after a restart while nothing is ever sent — which is precisely the case
  /// that matters once the app is off screen.
  Future<void> _applyAutoSend({String? previousHubId}) async {
    final hub = settings.defaultHubId;
    if (previousHubId != null && previousHubId != hub) {
      await engine.setAutoSend(previousHubId, false);
    }
    if (hub == null) return;
    await engine.setAutoSend(hub, settings.autoSendPhotos);
  }

  /// Sending a photo means exporting it out of the gallery to a temporary
  /// file first, and those copies are never cleaned up while the process
  /// lives — which, with the background engine, is days. Wipe them once
  /// nothing is queued or in flight and could still be pointing at one.
  void _scheduleExportCleanup() {
    if (!MobilePermissions.isMobile) return;
    _exportCleanup?.cancel();
    _exportCleanup = Timer(const Duration(minutes: 2), () {
      final idle =
          ref.read(transfersProvider).active.isEmpty &&
          (engine.mediaServer?.autoSend.isEmpty ?? true);
      if (!idle) {
        _scheduleExportCleanup();
        return;
      }
      unawaited(MediaSourcePhotoManager.clearExportedOriginals());
    });
  }

  /// iOS handed us a `BGAppRefreshTask` / `BGProcessingTask`: reconnect,
  /// push whatever is queued and give the task straight back. The budget for
  /// the next ones depends on not overstaying.
  Future<void> _onBackgroundTask(String id) async {
    try {
      engine.reconnectAll();
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (DateTime.now().isBefore(deadline) &&
          !engine.sessions.sessions.any((s) => s.isConnected)) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      await engine.flushAutoSend().timeout(const Duration(seconds: 12));
    } catch (_) {
      // Out of time or nothing reachable: the queue keeps it for next time.
    } finally {
      await PepoNative.backgroundTaskDone(id);
    }
  }

  /// Back to the foreground: reconnect, re-read the photo library if the
  /// permission was granted meanwhile, push the clipboard on mobile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    engine.reconnectAll();
    // Back from a kill or a long sleep: anything the queue still owes.
    unawaited(engine.flushAutoSend());
    // Started behind the Android service: the permission dialog waited for a window.
    unawaited(SystemNotifications.instance.promptOnce());
    final source = engine.ownMediaSource;
    if (source is MediaSourcePhotoManager && source.permissionMissing) {
      unawaited(
        MediaSourcePhotoManager.hasPermission().then((ok) {
          if (ok) return source.restart();
        }),
      );
    }
    _pushClipboard();
  }

  // ---------------------------------------------------------------------------
  // Clipboard (outgoing)

  /// Mobile can only read the clipboard in the foreground, so every chance
  /// counts: app resumed, a device connected, sharing switched on. Desktop
  /// is covered by the poll. Text queued by the share sheet or the tile
  /// while nobody was connected goes first.
  void _pushClipboard() {
    final clip = _clipboard;
    if (clip == null) return;
    final flushed = clip.flushPending();
    if (flushed != null) _reportClipboard(flushed);
    if (isDesktop || !clip.hasTargets) return;
    // Null before the first lifecycle event: cold start, we are in front.
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    unawaited(_sendClipboardFromWindow(clip));
  }

  /// Reading the clipboard goes through the window's platform channel: with
  /// Dart started behind the Android service and no window yet, nobody
  /// answers it (the call never completes), so it waits for one.
  Future<void> _sendClipboardFromWindow(ClipboardSync clip) async {
    if (!await PepoNative.hasActivity()) return;
    _reportClipboard(await clip.sendNow(onlyIfChanged: true, retries: 2));
  }

  /// Selected text shared to PepoConnect from another app.
  void _onSharedText(String text) {
    final clip = _clipboard;
    if (clip == null) return;
    unawaited(
      clip.sendText(text).then((r) {
        if (r.reason == ClipboardSendReason.noTarget) {
          toasts.show(ToastData(title: _l10n?.clipboardQueued ?? 'Se enviará al conectar'));
        } else {
          _reportClipboard(r);
        }
      }),
    );
  }

  /// Android quick tile / shortcut. The native side shows its own toast
  /// from the returned names, so nothing is shown here.
  Future<Map<String, Object?>> _onNativeClipboard(String text) async {
    final clip = _clipboard;
    if (clip == null) return {'sent': <String>[]};
    final r = await clip.sendText(text);
    return {'sent': r.sentTo, 'reason': r.reason.name};
  }

  void _reportClipboard(ClipboardSendResult r) {
    final l = _l10n;
    switch (r.reason) {
      case ClipboardSendReason.sent:
        final names = r.sentTo.join(', ');
        toasts.show(
          ToastData(
            title: l?.toastClipboardSent(names) ?? 'Portapapeles enviado a $names',
            severity: ToastSeverity.success,
            duration: const Duration(milliseconds: 2500),
          ),
        );
      case ClipboardSendReason.unchanged:
      case ClipboardSendReason.empty:
      case ClipboardSendReason.noTarget:
        break;
    }
  }

  // ---------------------------------------------------------------------------

  void _onSettings(AppSettings? prev, AppSettings next) {
    if (prev?.clipboardSharing != next.clipboardSharing) {
      _clipboard?.setEnabled(next.clipboardSharing, poll: isDesktop);
      engine.setClipboardSharing(next.clipboardSharing);
    }
    if (prev?.minimizeToTray != next.minimizeToTray) {
      DesktopIntegration.instance.minimizeToTray = next.minimizeToTray;
    }
    if (prev?.startWithSystem != next.startWithSystem && Autostart.isSupported) {
      unawaited(Autostart.setEnabled(next.startWithSystem));
    }
    if (prev?.separateByDevice != next.separateByDevice) {
      engine.setSeparateByDevice(next.separateByDevice);
    }
    if (prev?.allowExecutables != next.allowExecutables) {
      engine.setAllowExecutables(next.allowExecutables);
    }
    if (prev?.downloadRoot != next.downloadRoot && next.downloadRoot != null) {
      unawaited(engine.setDownloadRoot(next.downloadRoot!));
    }
    final name = next.deviceName;
    if (prev?.deviceName != name && name != null && name.isNotEmpty) {
      unawaited(engine.setDeviceName(name));
    }
    if (prev?.backgroundService != next.backgroundService) {
      unawaited(_updateBackground(ref.read(devicesProvider)));
    }
    if (prev?.autoSendPhotos != next.autoSendPhotos || prev?.defaultHubId != next.defaultHubId) {
      unawaited(_applyAutoSend(previousHubId: prev?.defaultHubId));
    }
  }

  void _onDevices(List<DeviceView>? prev, List<DeviceView> next) {
    unawaited(_updateBackground(next));
    // The shared-clipboard switch can arrive from the peer (device.info);
    // it lands after the connection event, so this is the trigger that
    // works the first time. It also turns the global switch on, which the
    // local toggle does on its own and the desktop poll depends on.
    bool wasOn(String id) => prev?.any((d) => d.deviceId == id && d.device.shareClipboard) ?? false;
    final turnedOn = next.any((d) => d.device.shareClipboard && !wasOn(d.deviceId));
    if (!turnedOn) return;
    if (!settings.clipboardSharing) {
      unawaited(
        ref.read(settingsProvider.notifier).update((s) => s.copyWith(clipboardSharing: true)),
      );
    }
    _pushClipboard();
  }

  /// The background engine: a foreground service on Android, the silent
  /// keep-alive loop on iOS. One switch, one rule — there is nothing to hold
  /// the process up for with no device paired.
  Future<void> _updateBackground(List<DeviceView> devices) async {
    final wanted = settings.backgroundService && devices.isNotEmpty;
    if (IosBackground.isSupported) {
      if (wanted) {
        await IosBackground.start();
      } else {
        await IosBackground.stop();
      }
      return;
    }
    if (!AndroidService.isSupported) return;
    final l = _l10n;
    if (wanted) {
      final connected = devices.where((d) => d.connected).map((d) => d.device.name).toList();
      final idle = l?.mobileServiceIdle ?? 'PepoConnect espera al PC';
      final text = connected.isEmpty
          ? idle
          : (l?.mobileServiceNotification(connected.join(', ')) ??
                'Conectado con ${connected.join(', ')}');
      await AndroidService.start(title: 'PepoConnect', text: text, idleText: idle);
    } else {
      await AndroidService.stop();
    }
  }

  void _onSharedFiles(List<String> shared) {
    var paths = shared;
    // The share sheet skips the transfers page, so the programs the setting
    // keeps back are explained here (the PC has its own switch as well).
    if (!settings.allowExecutables) {
      final blocked = paths
          .where((path) => ExecutableNames.isExecutable(p.basename(path)))
          .toList();
      if (blocked.isNotEmpty) {
        final l = _l10n;
        paths = paths.where((path) => !blocked.contains(path)).toList();
        toasts.show(
          ToastData(
            title: blocked.length == 1
                ? (l?.executableBlockedOne(p.basename(blocked.first)) ??
                      'No se ha enviado ${p.basename(blocked.first)}')
                : (l?.executableBlockedMany(blocked.length) ??
                      'No se han enviado ${blocked.length} ejecutables'),
            message: l?.executableBlocked ?? 'PepoConnect no envía programas hasta que lo permitas',
            severity: ToastSeverity.caution,
          ),
        );
      }
    }
    if (paths.isEmpty) return;
    final devices = ref.read(devicesProvider);
    final connected = devices.where((d) => d.connected).toList();
    DeviceView? target;
    final defaultId = settings.defaultHubId;
    if (defaultId != null) {
      target = connected.where((d) => d.deviceId == defaultId).firstOrNull;
    }
    target ??= connected.length == 1 ? connected.single : null;
    if (target != null) {
      unawaited(engine.sendFiles(target.deviceId, paths));
      toasts.show(ToastData(title: _l10n?.toastSentTo(target.device.name) ?? 'Enviando…'));
      return;
    }
    ref.read(pendingShareProvider.notifier).set(paths);
    router.go(AppRoutes.transfers);
  }

  void _onNotificationTap(String payload) {
    if (payload.startsWith('media:')) {
      final parts = payload.substring(6).split('/');
      if (parts.length == 2) {
        router.go(AppRoutes.gallery);
        router.push(AppRoutes.viewer(parts[0], parts[1]));
      }
    } else if (payload.startsWith('path:')) {
      unawaited(OpenHelper.showInFolder(payload.substring(5)));
    } else {
      router.go(AppRoutes.transfers);
    }
    if (DesktopIntegration.isSupported) unawaited(DesktopIntegration.instance.showWindow());
  }

  Widget? _thumb(Uint8List? bytes) =>
      bytes == null ? null : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);

  void _onEvent(EngineEvent e) {
    final l = _l10n;
    switch (e) {
      case GalleryChangedEvent(change: GalleryChange.newItem):
        final id = e.ids.firstOrNull;
        if (id == null) return;
        final name = _deviceName(e.deviceId);
        final gallery = engine.gallery.gallery(e.deviceId);
        final item = gallery.byId[id];
        final now = DateTime.now();
        final previous = _bursts[e.deviceId];
        final inBurst = previous != null && now.difference(previous.at) < _burstWindow;
        if (inBurst) previous.handle.dismiss();
        final ids = inBurst ? [...previous.ids, id] : [id];
        final allPhotos = ids.every((i) => gallery.byId[i]?.isVideo != true);
        final String title;
        if (ids.length == 1) {
          title = item?.isVideo == true
              ? (l?.toastNewVideo ?? 'Vídeo nuevo')
              : (l?.toastNewPhoto ?? 'Foto nueva');
        } else if (allPhotos) {
          title = l?.toastNewPhotos(ids.length) ?? '${ids.length} fotos nuevas';
        } else {
          title = l?.toastNewItems(ids.length) ?? '${ids.length} elementos nuevos';
        }
        void open() {
          router.go(AppRoutes.gallery);
          if (ids.length == 1) router.push(AppRoutes.viewer(e.deviceId, id));
        }
        final handle = toasts.show(
          ToastData(
            title: '$title · $name',
            message: item?.name,
            thumbnail: _thumb(engine.gallery.cachedThumbnail(e.deviceId, id)),
            actions: [
              ToastAction(label: l?.toastView ?? 'Ver', onPressed: open),
              ToastAction(
                label: l?.download ?? 'Descargar',
                onPressed: () => engine.downloadItems(e.deviceId, ids),
              ),
            ],
            onTap: open,
          ),
        );
        _bursts[e.deviceId] = _PhotoBurst(handle, ids, now);
        // One system notification per burst: the first item already alerted.
        if (settings.notifications && !inBurst) {
          unawaited(
            SystemNotifications.instance.show(
              title: '$title · $name',
              body: item?.name,
              payload: 'media:${e.deviceId}/$id',
              actions: ['Ver', l?.download ?? 'Descargar'],
              onAction: (i) {
                if (i == 1) {
                  engine.downloadItems(e.deviceId, [id]);
                } else {
                  _onNotificationTap('media:${e.deviceId}/$id');
                }
              },
            ),
          );
        }
      case TransferChangedEvent(record: final r) when r.state == TransferState.done:
        final name = _deviceName(r.deviceId);
        final title = r.isIncoming
            ? (l?.transferComplete ?? 'Transferencia completada')
            : (l?.toastSentTo(name) ?? 'Enviado a $name');
        final path = r.finalPath;
        toasts.show(
          ToastData(
            title: title,
            message: '${r.name} · ${formatBytes(r.size)}',
            severity: ToastSeverity.success,
            thumbnail: _thumb(
              r.sourceId == null ? null : engine.gallery.cachedThumbnail(r.deviceId, r.sourceId!),
            ),
            actions: [
              if (r.isIncoming && path != null)
                ToastAction(
                  label: l?.showInFolder ?? 'Mostrar en carpeta',
                  onPressed: () => OpenHelper.showInFolder(path),
                ),
              if (r.isIncoming && path != null)
                ToastAction(label: l?.open ?? 'Abrir', onPressed: () => OpenHelper.openFile(path)),
            ],
          ),
        );
        if (r.isIncoming && path != null && Platform.isAndroid) {
          unawaited(PepoNative.saveToDownloads(path, p.basename(path), r.mime));
        }
        if (settings.notifications && r.isIncoming) {
          unawaited(
            SystemNotifications.instance.show(
              title: title,
              body: '${r.name} · ${formatBytes(r.size)}',
              payload: path != null ? 'path:$path' : 'transfers',
            ),
          );
        }
        if (settings.sounds) {
          ref
              .read(transferChimeProvider)
              .ping(busy: () => ref.read(transfersProvider).activeCount > 0);
        }
      case TransferChangedEvent(record: final r) when r.state == TransferState.failed:
        toasts.show(
          ToastData(
            title: l?.transferFailed(r.name) ?? 'No se pudo transferir ${r.name}',
            message: l == null ? r.error : transferErrorLabel(l, r.error),
            severity: ToastSeverity.critical,
          ),
        );
      case OfferRejectedEvent(reason: ErrorCode.executable):
        final name = _deviceName(e.deviceId);
        toasts.show(
          ToastData(
            title:
                l?.executableRefusedTitle(e.name, name) ?? 'No se ha aceptado ${e.name} de $name',
            message: l?.executableRefusedBody ?? 'Los ejecutables están desactivados en Ajustes',
            severity: ToastSeverity.caution,
            actions: [
              ToastAction(
                label: l?.navSettings ?? 'Ajustes',
                onPressed: () => router.go(AppRoutes.settings),
              ),
            ],
          ),
        );
      case DevicePairedEngineEvent():
        _connectedToastAt[e.device.deviceId] = DateTime.now();
        toasts.show(
          ToastData(
            title: l?.activityPaired(e.device.name) ?? '${e.device.name} emparejado',
            severity: ToastSeverity.success,
          ),
        );
      case DeviceConnectionEvent():
        final name = _deviceName(e.deviceId);
        final last = _connectedToastAt[e.deviceId];
        if (e.connected) {
          _pushClipboard();
          if (last != null && DateTime.now().difference(last) < const Duration(seconds: 5)) {
            return;
          }
          _connectedToastAt[e.deviceId] = DateTime.now();
        }
        toasts.show(
          ToastData(
            title: e.connected
                ? (l?.toastDeviceConnected(name) ?? '$name conectado')
                : (l?.toastDeviceOffline(name) ?? '$name sin conexión'),
            severity: e.connected ? ToastSeverity.success : ToastSeverity.info,
            duration: const Duration(seconds: 3),
          ),
        );
      case ClipboardReceivedEvent():
        toasts.show(
          ToastData(
            title: l?.toastClipboardReceived(_deviceName(e.deviceId)) ?? 'Texto copiado',
            message: e.text.length > 80 ? '${e.text.substring(0, 80)}…' : e.text,
          ),
        );
      default:
        break;
    }
  }

  String _deviceName(String deviceId) => deviceLabel(ref.read(devicesProvider), deviceId);

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _exportCleanup?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _settingsSub?.close();
    _transfersSub?.close();
    _devicesSub?.close();
    _clipboard?.dispose();
    await _share?.dispose();
  }
}

class _PhotoBurst {
  _PhotoBurst(this.handle, this.ids, this.at);
  final ToastHandle handle;
  final List<String> ids;
  final DateTime at;
}
