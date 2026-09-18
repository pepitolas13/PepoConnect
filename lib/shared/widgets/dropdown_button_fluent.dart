import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import 'fluent_button.dart';
import 'flyout.dart';

/// One option of a [DropdownButtonFluent].
@immutable
class DropdownItem<T> {
  const DropdownItem({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Button with a chevron that opens a flyout of options; the current one
/// shows a check mark. Pass [hint] for the label when nothing is selected.
class DropdownButtonFluent<T> extends StatelessWidget {
  const DropdownButtonFluent({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint,
    this.style = FluentButtonStyle.secondary,
    this.icon,
    this.labelBuilder,
    this.menuWidth,
    this.placement = FlyoutPlacement.bottomStart,
  });

  final List<DropdownItem<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? hint;
  final FluentButtonStyle style;
  final IconData? icon;

  /// Overrides the button label (e.g. "Galería de Pixel 8").
  final String Function(DropdownItem<T>? selected)? labelBuilder;
  final double? menuWidth;
  final FlyoutPlacement placement;

  @override
  Widget build(BuildContext context) {
    DropdownItem<T>? selected;
    for (final item in items) {
      if (item.value == value) {
        selected = item;
        break;
      }
    }
    final label = labelBuilder?.call(selected) ?? selected?.label ?? hint ?? '';
    return Builder(
      builder: (buttonContext) => FluentButton(
        label: label,
        style: style,
        icon: icon ?? selected?.icon,
        trailingIcon: FluentIcons.chevron_down_12_regular,
        onPressed: onChanged == null || items.isEmpty
            ? null
            : () => showFlyout<void>(
                buttonContext,
                placement: placement,
                builder: (_) => ContextMenu(
                  width: menuWidth,
                  items: [
                    for (final item in items)
                      MenuItem(
                        label: item.label,
                        icon: item.icon,
                        checked: item.value == value,
                        onTap: () => onChanged!(item.value),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
