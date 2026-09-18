import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/fade_slide_switcher.dart';
import '../../shared/motion/motion.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import 'sections/about_section.dart';
import 'sections/devices_section.dart';
import 'sections/general_section.dart';
import 'sections/my_pc_section.dart';
import 'sections/notifications_section.dart';
import 'sections/phone_section.dart';
import 'sections/storage_section.dart';
import 'settings_widgets.dart';

enum SettingsSection { general, notifications, about }

/// Settings: a navigation list on the left and the section on the right;
/// under 600 px every section is stacked with a heading.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  /// Width under which the sections are stacked.
  static const double stackedBreakpoint = 600;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  SettingsSection _section = SettingsSection.general;

  static const _gap = SizedBox(height: Space.xl);

  String _label(AppLocalizations t, SettingsSection section) => switch (section) {
    SettingsSection.general => t.settingsGeneral,
    SettingsSection.notifications => t.settingsNotifications,
    SettingsSection.about => t.settingsAbout,
  };

  IconData _icon(SettingsSection section) => switch (section) {
    SettingsSection.general => FluentIcons.settings_20_regular,
    SettingsSection.notifications => FluentIcons.alert_20_regular,
    SettingsSection.about => FluentIcons.info_20_regular,
  };

  List<Widget> _content(SettingsSection section) => switch (section) {
    SettingsSection.general => [
      const MyPcSection(),
      _gap,
      const DevicesSection(),
      _gap,
      const GeneralSection(),
      if (!isDesktop) ...[_gap, const PhoneSection()],
      _gap,
      const StorageSection(),
    ],
    SettingsSection.notifications => const [NotificationsSection()],
    SettingsSection.about => const [AboutSection()],
  };

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < SettingsPage.stackedBreakpoint) return _stacked(t);
          return _split(t);
        },
      ),
    );
  }

  Widget _stacked(AppLocalizations t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.xxl),
      children: [
        Text(t.settingsTitle, style: context.text.title),
        for (final section in SettingsSection.values) ...[
          SettingsSectionTitle(_label(t, section)),
          ..._content(section),
        ],
      ],
    );
  }

  Widget _split(AppLocalizations t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 232,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.l, Space.l),
                child: Text(t.settingsTitle, style: context.text.title),
              ),
              for (final section in SettingsSection.values)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.xs),
                  child: _NavItem(
                    icon: _icon(section),
                    label: _label(t, section),
                    selected: section == _section,
                    onTap: () => setState(() => _section = section),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FadeSlideSwitcher(
            childKey: ValueKey(_section),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.l, Space.xxl, Space.xl, Space.xxl),
                  children: _content(_section),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Row of the settings navigation list: accent bar on the left when
/// selected, subtle hover fill.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final motion = Motion.of(context);
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        scaleOnPress: false,
        semanticLabel: label,
        hoverColor: selected ? colors.subtlePressed : null,
        child: SizedBox(
          height: 36,
          child: Row(
            children: [
              AnimatedContainer(
                duration: motion.normal,
                curve: Motion.standard,
                width: 3,
                height: selected ? 16 : 0,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: Space.m),
              Icon(icon, size: 20, color: colors.textPrimary),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text(
                  label,
                  style: selected ? text.bodyStrong : text.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
