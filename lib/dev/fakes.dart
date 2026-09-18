import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:pepo_core/pepo_core.dart';

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

/// Standard set of overrides for a shell without an engine.
List<Override> fakeOverrides({
  AppSettings settings = const AppSettings(),
  List<DeviceView>? devices,
  TransfersState transfers = const TransfersState(),
  int unread = 0,
}) => [
  settingsProvider.overrideWith(() => FakeSettingsNotifier(settings)),
  devicesProvider.overrideWith(() => FakeDevicesNotifier(devices ?? sampleDevices())),
  transfersProvider.overrideWith(() => FakeTransfersNotifier(transfers)),
  unreadActivityProvider.overrideWithValue(unread),
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
