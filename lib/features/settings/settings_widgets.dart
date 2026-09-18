import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/pepo_card.dart';
import '../../shared/widgets/pepo_dialog.dart';
import '../../shared/widgets/pepo_text_field.dart';
import '../../state/app_settings.dart';

/// One settings row (68 px): optional icon, title, description and the
/// control on the right. With [onTap] the whole row is pressable.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.trailing,
    this.onTap,
    this.minHeight = Sizes.settingsRow,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: colors.textPrimary),
              const SizedBox(width: Space.l),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.body),
                  if (description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description!,
                        style: text.caption.copyWith(color: colors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: Space.l), trailing!],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Pressable(onTap: onTap, scaleOnPress: false, semanticLabel: title, child: row);
  }
}

/// Rows inside one card, separated by 1 px dividers, with an optional
/// caption above the card.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.header, required this.children});

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: Text(header!, style: context.text.bodyStrong),
          ),
        PepoCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.divider),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Section title used when the sections are stacked (phone widths).
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.m),
      child: Text(title, style: context.text.subtitle),
    );
  }
}

/// One of the three theme choices: sun, moon or half-and-half, with an
/// accent border on the active one.
class ThemeCard extends StatelessWidget {
  const ThemeCard({
    super.key,
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static IconData iconFor(AppThemeMode mode) => switch (mode) {
    AppThemeMode.light => FluentIcons.weather_sunny_24_regular,
    AppThemeMode.dark => FluentIcons.weather_moon_24_regular,
    AppThemeMode.system => FluentIcons.dark_theme_24_regular,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SizedBox(
        width: 132,
        height: 92,
        child: PepoCard(
          selected: selected,
          onTap: onTap,
          padding: const EdgeInsets.all(Space.m),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconFor(mode), size: 24, color: selected ? colors.accent : colors.textPrimary),
              const SizedBox(height: Space.s),
              Text(
                label,
                style: (selected ? text.bodyStrong : text.body).copyWith(
                  color: selected ? colors.accent : colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three theme cards: light, dark, system.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key, required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Wrap(
      spacing: Space.m,
      runSpacing: Space.m,
      children: [
        ThemeCard(
          mode: AppThemeMode.light,
          label: t.themeLight,
          selected: value == AppThemeMode.light,
          onTap: () => onChanged(AppThemeMode.light),
        ),
        ThemeCard(
          mode: AppThemeMode.dark,
          label: t.themeDark,
          selected: value == AppThemeMode.dark,
          onTap: () => onChanged(AppThemeMode.dark),
        ),
        ThemeCard(
          mode: AppThemeMode.system,
          label: t.themeSystem,
          selected: value == AppThemeMode.system,
          onTap: () => onChanged(AppThemeMode.system),
        ),
      ],
    );
  }
}

/// Text prompt in a [PepoDialog]. Resolves with the trimmed value, or null
/// when cancelled or left empty.
Future<String?> showRenameDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required String placeholder,
}) => showPepoDialog<String>(
  context,
  builder: (_) => RenameDialog(title: title, initial: initial, placeholder: placeholder),
);

class RenameDialog extends StatefulWidget {
  const RenameDialog({
    super.key,
    required this.title,
    required this.initial,
    required this.placeholder,
  });

  final String title;
  final String initial;
  final String placeholder;

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return PepoDialog(
      title: widget.title,
      content: PepoTextField(
        controller: _controller,
        autofocus: true,
        placeholder: widget.placeholder,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        FluentButton(label: t.cancel, onPressed: () => Navigator.of(context).pop()),
        FluentButton.primary(label: t.save, onPressed: _submit),
      ],
    );
  }
}

/// "Are you sure?" dialog. Resolves true when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final result = await showPepoDialog<bool>(
    context,
    builder: (context) {
      final t = context.t;
      return PepoDialog(
        title: title,
        content: Text(body),
        actions: [
          FluentButton(label: t.cancel, onPressed: () => Navigator.of(context).pop(false)),
          FluentButton.primary(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
