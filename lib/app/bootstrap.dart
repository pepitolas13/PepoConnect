import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pepo_core/pepo_core.dart';

import '../state/app_settings.dart';
import '../state/stores.dart';

/// Command line options: `--profile=<name>` runs a second, independent
/// instance (own data dir, port and name); `--minimized` starts hidden.
class LaunchOptions {
  const LaunchOptions({this.profile, this.minimized = false, this.port});

  final String? profile;
  final bool minimized;
  final int? port;

  static LaunchOptions parse(List<String> args) {
    String? profile;
    int? port;
    var minimized = false;
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      if (a.startsWith('--profile=')) {
        profile = a.substring('--profile='.length);
      } else if (a == '--profile' && i + 1 < args.length) {
        profile = args[++i];
      } else if (a.startsWith('--port=')) {
        port = int.tryParse(a.substring('--port='.length));
      } else if (a == '--minimized') {
        minimized = true;
      }
    }
    return LaunchOptions(profile: profile, minimized: minimized, port: port);
  }
}

/// Where this instance keeps its data.
class AppPaths {
  const AppPaths({required this.dataDir, required this.defaultDownloadRoot, required this.cacheDir});

  final String dataDir;
  final String defaultDownloadRoot;
  final String cacheDir;

  static Future<AppPaths> resolve(LaunchOptions options) async {
    final portable = Platform.environment['PEPOCONNECT_DATA_DIR'];
    String dataDir;
    if (portable != null && portable.isNotEmpty) {
      dataDir = portable;
    } else if (Platform.isWindows) {
      dataDir = p.join(Platform.environment['APPDATA'] ?? (await getApplicationSupportDirectory()).path, 'PepoConnect');
    } else {
      dataDir = (await getApplicationSupportDirectory()).path;
    }
    if (options.profile != null) dataDir = p.join(dataDir, 'profiles', options.profile!);
    String downloads;
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      downloads = p.join((ext ?? await getApplicationDocumentsDirectory()).path, 'PepoConnect');
    } else if (Platform.isIOS) {
      downloads = p.join((await getApplicationDocumentsDirectory()).path, 'PepoConnect');
    } else if (Platform.isWindows) {
      downloads = p.join(Platform.environment['USERPROFILE'] ?? dataDir, 'Pictures', 'PepoConnect');
    } else {
      final home = Platform.environment['HOME'] ?? dataDir;
      final xdgPictures = Platform.environment['XDG_PICTURES_DIR'];
      downloads = p.join(xdgPictures ?? p.join(home, 'Pictures'), 'PepoConnect');
    }
    if (options.profile != null) downloads = p.join(downloads, options.profile!);
    final cache = p.join(dataDir, 'cache');
    return AppPaths(dataDir: dataDir, defaultDownloadRoot: downloads, cacheDir: cache);
  }
}

DevicePlatform currentPlatform() {
  if (Platform.isWindows) return DevicePlatform.windows;
  if (Platform.isLinux) return DevicePlatform.linux;
  if (Platform.isAndroid) return DevicePlatform.android;
  if (Platform.isIOS) return DevicePlatform.ios;
  if (Platform.isMacOS) return DevicePlatform.macos;
  return DevicePlatform.unknown;
}

bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Default device name: host name on desktop, model on mobile.
Future<({String name, String? model})> defaultDeviceIdentity() async {
  final info = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      final model = a.model.isNotEmpty ? a.model : 'Android';
      final brand = a.brand.isNotEmpty ? '${a.brand[0].toUpperCase()}${a.brand.substring(1)} ' : '';
      return (name: model.toLowerCase().startsWith(brand.trim().toLowerCase()) ? model : '$brand$model', model: model);
    }
    if (Platform.isIOS) {
      final i = await info.iosInfo;
      return (name: i.name, model: i.utsname.machine);
    }
    if (Platform.isWindows) {
      final w = await info.windowsInfo;
      return (name: w.computerName.isNotEmpty ? w.computerName : Platform.localHostname, model: null);
    }
    if (Platform.isLinux) {
      final l = await info.linuxInfo;
      return (name: Platform.localHostname, model: l.prettyName);
    }
  } catch (_) {}
  return (name: Platform.localHostname, model: null);
}

/// Builds and starts the engine for this platform.
Future<PepoEngine> startEngine({
  required AppSettings settings,
  required AppPaths paths,
  required LaunchOptions options,
  MediaSource? mediaSource,
  List<String> mediaRoots = const [],
  OfferPolicy? offerPolicy,
  DeletePolicy? deletePolicy,
}) async {
  final identity = await defaultDeviceIdentity();
  final pkg = await PackageInfo.fromPlatform();
  final platform = currentPlatform();
  final role = platform.isMobile ? DeviceRole.phone : DeviceRole.both;
  final battery = Battery();
  var name = settings.deviceName ?? identity.name;
  if (options.profile != null && settings.deviceName == null) name = '$name (${options.profile})';
  final config = EngineConfig(
    dataDir: paths.dataDir,
    downloadRoot: settings.downloadRoot ?? paths.defaultDownloadRoot,
    deviceName: name,
    platform: platform,
    role: role,
    appVersion: pkg.version,
    model: identity.model,
    separateByDevice: settings.separateByDevice,
    listenPort: options.port ?? (options.profile == null ? defaultListenPort : defaultListenPort + 10 + options.profile.hashCode.abs() % 50),
    mediaRoots: mediaRoots,
    udpDiscovery: !Platform.isIOS,
    profile: options.profile,
  );
  final engine = PepoEngine(
    config,
    deviceStore: JsonDeviceStore(paths.dataDir),
    transferStore: JsonTransferStore(paths.dataDir),
    mediaStateStore: JsonMediaStateStore(paths.dataDir),
    mediaSource: mediaSource,
    offerPolicy: offerPolicy,
    deletePolicy: deletePolicy,
    localStatus: () => _lastStatus,
  );
  await engine.start();
  // Battery/charging for the peer's device header; refreshed every minute.
  Future<void> refreshStatus() async {
    try {
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;
      _lastStatus = DeviceStatus(
        battery: level,
        charging: state == BatteryState.charging || state == BatteryState.full,
        addresses: await localIPv4Addresses(),
        listenPort: engine.listenPort,
      );
    } catch (_) {
      _lastStatus = DeviceStatus(addresses: await localIPv4Addresses(), listenPort: engine.listenPort);
    }
    engine.sessions.broadcastStatus();
  }

  await refreshStatus();
  Stream<void>.periodic(const Duration(minutes: 1)).listen((_) => refreshStatus());
  // Network changes: reconnect right away.
  Connectivity().onConnectivityChanged.listen((_) => engine.reconnectAll());
  return engine;
}

DeviceStatus _lastStatus = const DeviceStatus();
