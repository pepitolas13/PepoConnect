import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:pepo_core/pepo_core.dart' show DevicePlatform;

import '../theme/tokens.dart';

/// Silhouette family of a device.
enum DeviceKind {
  phone,
  tablet,
  laptop,
  desktop,
  unknown;

  /// Picks a silhouette from the wire platform and, when known, the model
  /// (tablets are only told apart by model name).
  static DeviceKind fromPlatform(DevicePlatform platform, {String? model}) {
    final m = (model ?? '').toLowerCase();
    switch (platform) {
      case DevicePlatform.android:
        return m.contains('tab') || m.contains('pad') ? DeviceKind.tablet : DeviceKind.phone;
      case DevicePlatform.ios:
        return m.startsWith('ipad') ? DeviceKind.tablet : DeviceKind.phone;
      case DevicePlatform.macos:
        return m.contains('book') ? DeviceKind.laptop : DeviceKind.desktop;
      case DevicePlatform.windows:
      case DevicePlatform.linux:
        return m.contains('laptop') || m.contains('book') ? DeviceKind.laptop : DeviceKind.desktop;
      case DevicePlatform.unknown:
        return DeviceKind.unknown;
    }
  }
}

/// Thin-line device silhouette (Fluent icons), 20/24/32/48 px.
class DeviceIcon extends StatelessWidget {
  const DeviceIcon({super.key, required this.kind, this.size = 20, this.color});

  DeviceIcon.fromPlatform(
    DevicePlatform platform, {
    super.key,
    String? model,
    this.size = 20,
    this.color,
  }) : kind = DeviceKind.fromPlatform(platform, model: model);

  final DeviceKind kind;
  final double size;
  final Color? color;

  static IconData iconFor(DeviceKind kind, double size) {
    if (size >= 48) {
      return switch (kind) {
        DeviceKind.phone => FluentIcons.phone_48_regular,
        DeviceKind.tablet => FluentIcons.tablet_48_regular,
        DeviceKind.laptop => FluentIcons.laptop_48_regular,
        DeviceKind.desktop => FluentIcons.desktop_32_regular,
        DeviceKind.unknown => FluentIcons.phone_desktop_24_regular,
      };
    }
    if (size >= 32) {
      return switch (kind) {
        DeviceKind.phone => FluentIcons.phone_32_regular,
        DeviceKind.tablet => FluentIcons.tablet_32_regular,
        DeviceKind.laptop => FluentIcons.laptop_32_regular,
        DeviceKind.desktop => FluentIcons.desktop_32_regular,
        DeviceKind.unknown => FluentIcons.phone_desktop_24_regular,
      };
    }
    if (size >= 24) {
      return switch (kind) {
        DeviceKind.phone => FluentIcons.phone_24_regular,
        DeviceKind.tablet => FluentIcons.tablet_24_regular,
        DeviceKind.laptop => FluentIcons.laptop_24_regular,
        DeviceKind.desktop => FluentIcons.desktop_24_regular,
        DeviceKind.unknown => FluentIcons.phone_desktop_24_regular,
      };
    }
    return switch (kind) {
      DeviceKind.phone => FluentIcons.phone_20_regular,
      DeviceKind.tablet => FluentIcons.tablet_20_regular,
      DeviceKind.laptop => FluentIcons.laptop_20_regular,
      DeviceKind.desktop => FluentIcons.desktop_20_regular,
      DeviceKind.unknown => FluentIcons.phone_desktop_20_regular,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Icon(iconFor(kind, size), size: size, color: color ?? context.pepo.textPrimary);
  }
}
