import 'package:meta/meta.dart';

import '../net/peer_listener.dart';
import '../protocol/models.dart';

/// Static configuration of a [PepoEngine] instance. Serializable so it can
/// cross an isolate boundary (Android foreground service).
@immutable
class EngineConfig {
  const EngineConfig({
    required this.dataDir,
    required this.downloadRoot,
    required this.deviceName,
    required this.platform,
    required this.role,
    required this.appVersion,
    this.model,
    this.separateByDevice = true,
    this.listenPort = defaultListenPort,
    this.mediaRoots = const [],
    this.udpDiscovery = true,
    this.profile,
    this.fastLane = true,
    this.nativeLibraryPath,
  });

  /// Identity, database, caches, logs.
  final String dataDir;

  /// Root folder for received files.
  final String downloadRoot;
  final String deviceName;
  final DevicePlatform platform;
  final DeviceRole role;
  final String appVersion;
  final String? model;
  final bool separateByDevice;
  final int listenPort;

  /// Folders served as this device's gallery (Linux phones, desktop
  /// tests). Empty means no gallery is published.
  final List<String> mediaRoots;
  final bool udpDiscovery;

  /// Optional profile name (second instance on the same PC).
  final String? profile;

  /// Use the Rust bulk engine when its library can be loaded.
  final bool fastLane;

  /// Explicit path of the fast lane library (tests); otherwise it is looked
  /// up next to the executable.
  final String? nativeLibraryPath;

  EngineConfig copyWith({
    String? downloadRoot,
    String? deviceName,
    bool? separateByDevice,
    List<String>? mediaRoots,
    DeviceRole? role,
  }) => EngineConfig(
    dataDir: dataDir,
    downloadRoot: downloadRoot ?? this.downloadRoot,
    deviceName: deviceName ?? this.deviceName,
    platform: platform,
    role: role ?? this.role,
    appVersion: appVersion,
    model: model,
    separateByDevice: separateByDevice ?? this.separateByDevice,
    listenPort: listenPort,
    mediaRoots: mediaRoots ?? this.mediaRoots,
    udpDiscovery: udpDiscovery,
    profile: profile,
    fastLane: fastLane,
    nativeLibraryPath: nativeLibraryPath,
  );

  Map<String, dynamic> toJson() => {
    'dataDir': dataDir,
    'downloadRoot': downloadRoot,
    'deviceName': deviceName,
    'platform': platform.code,
    'role': role.code,
    'appVersion': appVersion,
    'model': ?model,
    'separateByDevice': separateByDevice,
    'listenPort': listenPort,
    'mediaRoots': mediaRoots,
    'udpDiscovery': udpDiscovery,
    'profile': ?profile,
    'fastLane': fastLane,
    'nativeLibraryPath': ?nativeLibraryPath,
  };

  factory EngineConfig.fromJson(Map<String, dynamic> j) => EngineConfig(
    dataDir: j['dataDir'] as String,
    downloadRoot: j['downloadRoot'] as String,
    deviceName: j['deviceName'] as String,
    platform: DevicePlatform.fromCode(j['platform'] as String?),
    role: DeviceRole.fromCode(j['role'] as String?),
    appVersion: j['appVersion'] as String,
    model: j['model'] as String?,
    separateByDevice: j['separateByDevice'] as bool? ?? true,
    listenPort: j['listenPort'] as int? ?? defaultListenPort,
    mediaRoots: (j['mediaRoots'] as List<dynamic>? ?? const []).cast<String>(),
    udpDiscovery: j['udpDiscovery'] as bool? ?? true,
    profile: j['profile'] as String?,
    fastLane: j['fastLane'] as bool? ?? true,
    nativeLibraryPath: j['nativeLibraryPath'] as String?,
  );
}
