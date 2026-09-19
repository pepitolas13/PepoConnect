import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/mobile_permissions.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/skeleton.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_button.dart';
import 'settings_widgets.dart';

/// Current state of the mobile permissions. Re-read with
/// `ref.invalidate` after a request.
final mobilePermissionsProvider = FutureProvider<MobilePermissionState>(
  (ref) => MobilePermissions.check(),
);

enum MobilePermission { photos, notifications, battery }

/// "Photos and videos / Notifications / No battery restriction" rows with a
/// check when granted and an "Allow" button otherwise. Used by the mobile
/// onboarding and by the settings page.
class PermissionRows extends ConsumerWidget {
  const PermissionRows({super.key});

  Future<void> _request(WidgetRef ref, MobilePermission permission) async {
    switch (permission) {
      case MobilePermission.photos:
        await MobilePermissions.requestPhotos();
      case MobilePermission.notifications:
        await MobilePermissions.requestNotifications();
      case MobilePermission.battery:
        await MobilePermissions.requestBattery();
    }
    ref.invalidate(mobilePermissionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final state = ref.watch(mobilePermissionsProvider);
    final value = state.value;
    if (value == null && state.isLoading) {
      return const Column(children: [_LoadingRow(), _LoadingRow(), _LoadingRow()]);
    }
    final granted = value ?? _none;
    // A limited selection reads as "granted" to iOS but hides every photo
    // taken afterwards, and only the system settings can widen it.
    final limited = granted.photos && granted.photosLimited;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PermissionRow(
          icon: FluentIcons.image_multiple_24_regular,
          title: t.setPermissionPhotos,
          description: limited ? t.setPermissionPhotosLimited : t.setPermissionPhotosBody,
          granted: granted.photos && !limited,
          allowLabel: limited ? t.setOpenSystemSettings : null,
          onAllow: () => limited
              ? MobilePermissions.openSystemSettings()
              : _request(ref, MobilePermission.photos),
        ),
        Divider(height: 1, color: context.pepo.divider),
        PermissionRow(
          icon: FluentIcons.alert_24_regular,
          title: t.notifications,
          description: t.setPermissionNotificationsBody,
          granted: granted.notifications,
          onAllow: () => _request(ref, MobilePermission.notifications),
        ),
        Divider(height: 1, color: context.pepo.divider),
        PermissionRow(
          icon: FluentIcons.battery_saver_24_regular,
          title: t.setPermissionBattery,
          description: t.setPermissionBatteryBody,
          granted: granted.batteryUnrestricted,
          onAllow: () => _request(ref, MobilePermission.battery),
        ),
      ],
    );
  }

  static const MobilePermissionState _none = MobilePermissionState(
    photos: false,
    notifications: false,
    batteryUnrestricted: false,
  );
}

/// One permission: check mark and "Granted" or an "Allow" button.
class PermissionRow extends StatelessWidget {
  const PermissionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onAllow,
    this.allowLabel,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onAllow;

  /// Overrides the "Allow" label when the fix is somewhere else.
  final String? allowLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    return SettingsRow(
      icon: icon,
      title: title,
      description: description,
      trailing: granted
          ? Semantics(
              label: t.setGranted,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.checkmark_circle_20_filled, size: 20, color: colors.success),
                  const SizedBox(width: Space.xs),
                  Text(t.setGranted, style: context.text.caption.copyWith(color: colors.success)),
                ],
              ),
            )
          : FluentButton(label: allowLabel ?? t.setAllow, onPressed: onAllow),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: Sizes.settingsRow,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.l),
        child: Row(
          children: [
            Skeleton(width: 20, height: 20),
            SizedBox(width: Space.l),
            Expanded(child: Skeleton(height: 14)),
            SizedBox(width: Space.l),
            Skeleton(width: 72, height: 32),
          ],
        ),
      ),
    );
  }
}
