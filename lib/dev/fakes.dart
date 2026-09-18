import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:pepo_core/pepo_core.dart';

import '../app/app_services.dart';
import '../features/gallery/thumbnail_lookup.dart';
import '../shared/motion/toast.dart';
import '../state/activity.dart';
import '../state/app_settings.dart';
import '../state/engine_providers.dart';

/// In-memory settings for the dev gallery and widget tests.
class FakeSettingsNotifier extends SettingsNotifier {
  FakeSettingsNotifier([this.initial = const AppSettings()]);

  final AppSettings initial;

  @override
  AppSettings build() => initial;

  @override
  Future<void> update(AppSettings Function(AppSettings current) change) async {
    state = change(state);
  }
}

/// Devices without an engine.
class FakeDevicesNotifier extends DevicesNotifier {
  FakeDevicesNotifier([this.initial = const []]);

  final List<DeviceView> initial;

  @override
  List<DeviceView> build() => initial;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> forget(String deviceId) async {
    state = state.where((d) => d.deviceId != deviceId).toList();
  }

  @override
  Future<void> rename(String deviceId, String name) async {
    state = [
      for (final d in state)
        if (d.deviceId == deviceId)
          DeviceView(
            device: d.device.copyWith(name: name),
            connected: d.connected,
            connecting: d.connecting,
            status: d.status,
            connectedAt: d.connectedAt,
          )
        else
          d,
    ];
  }

  @override
  Future<void> setAutoDownload(String deviceId, bool value) async {}

  @override
  Future<void> setConvertHeic(String deviceId, bool value) async {}

  @override
  Future<void> setShareClipboard(String deviceId, bool value) async {}

  @override
  void reconnect() {}
}

/// Transfers without an engine. [tick] advances every active transfer.
class FakeTransfersNotifier extends TransfersNotifier {
  FakeTransfersNotifier([this.initial = const TransfersState()]);

  final TransfersState initial;

  @override
  TransfersState build() => initial;

  @override
  Future<List<TransferRecord>> send(String deviceId, List<String> paths) async => const [];

  @override
  Future<void> cancel(int id) async {
    state = state.copyWith(active: state.active.where((t) => t.id != id).toList());
  }

  @override
  Future<void> pause(int id) async {
    for (final t in state.active) {
      if (t.id == id) t.state = TransferState.paused;
    }
    state = state.copyWith(active: state.active.toList());
  }

  @override
  Future<void> resume(int id) async {
    state = state.copyWith(
      active: [
        for (final t in state.active)
          if (t.id == id) (t.copy()..state = TransferState.active) else t,
      ],
    );
  }

  /// Moves every active transfer forward by [fraction] of its size.
  void tick([double fraction = 0.1]) {
    final active = <TransferRecord>[];
    final history = state.history.toList();
    for (final t in state.active) {
      if (t.state == TransferState.paused) {
        active.add(t);
        continue;
      }
      t.state = TransferState.active;
      t.bytesDone = (t.bytesDone + (t.size * fraction).round()).clamp(0, t.size);
      if (t.bytesDone >= t.size) {
        t.state = TransferState.done;
        t.finishedAt = DateTime.now();
        history.insert(0, t);
      } else {
        active.add(t);
      }
    }
    state = TransfersState(active: active, history: history);
  }

  void add(TransferRecord record) {
    state = state.copyWith(active: [...state.active, record]);
  }
}

DeviceView fakeDevice({
  required String id,
  required String name,
  DevicePlatform platform = DevicePlatform.android,
  String? model,
  bool connected = true,
  bool connecting = false,
  int? battery = 100,
  bool charging = false,
  DateTime? lastSeen,
}) => DeviceView(
  device: PairedDevice(
    deviceId: id.padRight(16, '0'),
    name: name,
    platform: platform,
    role: platform.isMobile ? DeviceRole.phone : DeviceRole.both,
    fingerprint: 'ab' * 32,
    psk: Uint8List(32),
    weInitiate: false,
    pairedAt: DateTime(2026, 3, 12, 10, 0),
    model: model,
    lastSeen: lastSeen ?? DateTime.now().subtract(const Duration(minutes: 9)),
  ),
  connected: connected,
  connecting: connecting,
  status: DeviceStatus(battery: battery, charging: charging),
  connectedAt: connected ? DateTime.now().subtract(const Duration(minutes: 9)) : null,
);

TransferRecord fakeTransfer({
  required int id,
  required String deviceId,
  required String name,
  int size = 12 * 1024 * 1024,
  int bytesDone = 0,
  TransferDirection direction = TransferDirection.send,
  TransferState state = TransferState.active,
}) => TransferRecord(
  id: id,
  deviceId: deviceId.padRight(16, '0'),
  direction: direction,
  name: name,
  size: size,
  mime: 'image/jpeg',
  createdAt: DateTime.now().subtract(Duration(seconds: id)),
  state: state,
  bytesDone: bytesDone,
  bytesPerSecond: 8 * 1024 * 1024,
);

/// Every provider a page can touch, without an engine: settings, devices,
/// transfers, gallery, activity, thumbnails and toasts. [unread] pins the
/// unread counter; leave it null so it follows [activity].
List<Override> fakeOverrides({
  AppSettings settings = const AppSettings(),
  List<DeviceView>? devices,
  TransfersState transfers = const TransfersState(),
  int? unread,
  List<GalleryEntry> entries = const [],
  Map<String, Uint8List> thumbnails = const {},
  bool galleryLoaded = true,
  List<ActivityEntry> activity = const [],
  ToastService? toasts,
}) => [
  settingsProvider.overrideWith(() => FakeSettingsNotifier(settings)),
  devicesProvider.overrideWith(() => FakeDevicesNotifier(devices ?? sampleDevices())),
  transfersProvider.overrideWith(() => FakeTransfersNotifier(transfers)),
  galleryProvider.overrideWith2(
    (deviceId) => FakeGalleryNotifier(
      deviceId,
      entries: entries,
      thumbnails: thumbnails,
      loaded: galleryLoaded,
    ),
  ),
  activityProvider.overrideWith(() => FakeActivityNotifier(activity)),
  if (unread != null) unreadActivityProvider.overrideWithValue(unread),
  thumbnailLookupProvider.overrideWithValue((deviceId, id) => thumbnails[id]),
  toastServiceProvider.overrideWithValue(toasts ?? ToastService()),
];

List<DeviceView> sampleDevices() => [
  fakeDevice(id: 'pixel8', name: 'Pixel 8', model: 'Pixel 8', battery: 100),
  fakeDevice(
    id: 'ipad',
    name: 'iPad de Daniel',
    platform: DevicePlatform.ios,
    model: 'iPad13,1',
    connected: false,
    battery: 64,
    lastSeen: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
  ),
  fakeDevice(
    id: 'georgy',
    name: 'GeorGY',
    platform: DevicePlatform.windows,
    connected: false,
    connecting: true,
    battery: null,
    lastSeen: DateTime(2026, 3, 12, 18, 4),
  ),
];

/// A 1×1 transparent PNG.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Device id as padded by [fakeDevice].
String fakeDeviceId(String id) => id.padRight(16, '0');

/// Gallery without an engine: fixed entries, thumbnails from [thumbnails].
class FakeGalleryNotifier extends GalleryNotifier {
  FakeGalleryNotifier(
    super.deviceId, {
    this.entries = const [],
    this.thumbnails = const {},
    this.loaded = true,
  });

  final List<GalleryEntry> entries;
  final Map<String, Uint8List> thumbnails;
  final bool loaded;
  final List<GalleryEntry> downloaded = [];
  final List<GalleryEntry> deleted = [];
  int refreshes = 0;

  @override
  GalleryState build() {
    final scoped = deviceId == null
        ? entries
        : entries.where((e) => e.deviceId == deviceId).toList();
    return GalleryState(entries: scoped, total: scoped.length, loaded: loaded);
  }

  @override
  Future<void> refresh() async {
    refreshes++;
  }

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> setFilter(Set<MediaKind>? kinds) async {}

  @override
  Future<Uint8List?> thumbnail(GalleryEntry e) async => thumbnails[e.id];

  @override
  Future<Uint8List?> preview(GalleryEntry e) async => null;

  @override
  Future<void> download(Iterable<GalleryEntry> entries) async => downloaded.addAll(entries);

  @override
  Future<void> dismiss(GalleryEntry e) async {}

  @override
  Future<List<String>> deleteOnDevice(Iterable<GalleryEntry> entries) async {
    deleted.addAll(entries);
    return [for (final e in entries) e.id];
  }
}

/// Activity without a store.
class FakeActivityNotifier extends ActivityNotifier {
  FakeActivityNotifier([this.initial = const []]);

  final List<ActivityEntry> initial;

  @override
  List<ActivityEntry> build() => initial;

  @override
  void markAllRead() {
    state = [for (final a in state) a.read ? a : a.copyWith(read: true)];
  }

  @override
  void clear() => state = const [];
}

GalleryEntry fakeEntry({
  required String id,
  required DateTime takenAt,
  String deviceId = 'pixel8',
  String? name,
  MediaKind kind = MediaKind.image,
  int size = 3 * 1024 * 1024,
  MediaState state = MediaState.previewed,
  String? localPath,
  int? durationMs,
}) => GalleryEntry(
  deviceId: fakeDeviceId(deviceId),
  item: MediaItem(
    id: id,
    kind: kind,
    name: name ?? (kind == MediaKind.video ? 'VID_$id.mp4' : 'IMG_$id.jpg'),
    width: 4000,
    height: 3000,
    takenAt: takenAt.toUtc(),
    size: size,
    mime: kind == MediaKind.video ? 'video/mp4' : 'image/jpeg',
    durationMs: durationMs,
  ),
  state: state,
  localPath: localPath,
);

ActivityEntry fakeActivity({
  required String id,
  required DateTime at,
  ActivityKind kind = ActivityKind.newPhoto,
  String deviceId = 'pixel8',
  String deviceName = 'Pixel 8',
  String? fileName,
  String? mediaId,
  String? path,
  String? text,
  bool read = false,
}) => ActivityEntry(
  id: id,
  at: at,
  kind: kind,
  deviceId: fakeDeviceId(deviceId),
  deviceName: deviceName,
  fileName: fileName,
  mediaId: mediaId,
  path: path,
  text: text,
  read: read,
);
