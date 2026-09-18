import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';

import '../l10n/generated/app_localizations.dart';
import '../platform/android_service.dart';
import '../platform/autostart.dart';
import '../platform/clipboard_sync.dart';
import '../platform/desktop_integration.dart';
import '../platform/notifications.dart';
import '../platform/open_helper.dart';
import '../platform/pepo_native.dart';
import '../platform/share_intake.dart';
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
class AppServices {
  AppServices(this.ref, this.router);

  final ProviderContainer ref;
  final GoRouter router;
  final List<StreamSubscription<dynamic>> _subs = [];
  ClipboardSync? _clipboard;
  ShareIntake? _share;
  ProviderSubscription<AppSettings>? _settingsSub;
  ProviderSubscription<TransfersState>? _transfersSub;
  ProviderSubscription<List<DeviceView>>? _devicesSub;
  AppLocalizations? _l10n;
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
    });
    _devicesSub = ref.listen<List<DeviceView>>(devicesProvider, (_, next) => _updateService(next));
    _clipboard = ClipboardSync(engine)..start(poll: isDesktop);
    _clipboard!.setEnabled(settings.clipboardSharing, poll: isDesktop);
    engine.setClipboardSharing(settings.clipboardSharing);
    if (ShareIntake.isSupported) {
      _share = ShareIntake(onFiles: _onSharedFiles, onText: (t) => engine.sendClipboard(t));
      await _share!.start();
    }
    if (Autostart.isSupported) unawaited(Autostart.refresh());
    SystemNotifications.instance.onTap = _onNotificationTap;
    await _updateService(ref.read(devicesProvider));
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
    if (prev?.downloadRoot != next.downloadRoot && next.downloadRoot != null) {
      unawaited(engine.setDownloadRoot(next.downloadRoot!));
    }
    final name = next.deviceName;
    if (prev?.deviceName != name && name != null && name.isNotEmpty) {
      unawaited(engine.setDeviceName(name));
    }
    if (prev?.backgroundService != next.backgroundService) {
      unawaited(_updateService(ref.read(devicesProvider)));
    }
  }

  Future<void> _updateService(List<DeviceView> devices) async {
    if (!AndroidService.isSupported) return;
    final l = _l10n;
    if (settings.backgroundService && devices.isNotEmpty) {
      final connected = devices.where((d) => d.connected).map((d) => d.device.name).toList();
      final text = connected.isEmpty
          ? (l?.mobileServiceIdle ?? 'PepoConnect espera al PC')
          : (l?.mobileServiceNotification(connected.join(', ')) ??
                'Conectado con ${connected.join(', ')}');
      await AndroidService.start(title: 'PepoConnect', text: text);
    } else {
      await AndroidService.stop();
    }
  }

  void _onSharedFiles(List<String> paths) {
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
        final item = engine.gallery.gallery(e.deviceId).byId[id];
        final title = item?.isVideo == true
            ? (l?.toastNewVideo ?? 'Vídeo nuevo')
            : (l?.toastNewPhoto ?? 'Foto nueva');
        toasts.show(
          ToastData(
            title: '$title · $name',
            message: item?.name,
            thumbnail: _thumb(engine.gallery.cachedThumbnail(e.deviceId, id)),
            actions: [
              ToastAction(
                label: 'Ver',
                onPressed: () {
                  router.go(AppRoutes.gallery);
                  router.push(AppRoutes.viewer(e.deviceId, id));
                },
              ),
              ToastAction(
                label: l?.download ?? 'Descargar',
                onPressed: () => engine.downloadItems(e.deviceId, [id]),
              ),
            ],
            onTap: () {
              router.go(AppRoutes.gallery);
              router.push(AppRoutes.viewer(e.deviceId, id));
            },
          ),
        );
        if (settings.notifications) {
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
      case TransferChangedEvent(record: final r) when r.state == TransferState.failed:
        toasts.show(
          ToastData(
            title: l?.transferFailed(r.name) ?? 'No se pudo transferir ${r.name}',
            message: r.error,
            severity: ToastSeverity.critical,
          ),
        );
      case DevicePairedEngineEvent():
        toasts.show(
          ToastData(
            title: l?.toastDeviceConnected(e.device.name) ?? '${e.device.name} conectado',
            severity: ToastSeverity.success,
          ),
        );
      case DeviceConnectionEvent():
        final name = _deviceName(e.deviceId);
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
