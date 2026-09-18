import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../motion/pressable.dart';
import '../theme/tokens.dart';

/// Where a flyout opens relative to its anchor.
enum FlyoutPlacement {
  bottomStart,
  bottomEnd,
  bottomCenter,
  topStart,
  topEnd,
  rightStart,
  leftStart,
}

/// Floating surface: radius 8, 1 px stroke, flyout shadow.
class FlyoutSurface extends StatelessWidget {
  const FlyoutSurface({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(Space.xs),
    this.constraints,
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        constraints: constraints,
        padding: padding,
        decoration: BoxDecoration(
          color: colors.flyoutSurface,
          borderRadius: Radii.cardRadius,
          border: Border.all(color: colors.cardStroke),
          boxShadow: PepoShadows.flyout,
        ),
        child: child,
      ),
    );
  }
}

/// Opens [builder] in a flyout anchored to [anchor] (defaults to [context])
/// or at [position]. Tap outside, Esc and the back button close it.
Future<T?> showFlyout<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  BuildContext? anchor,
  Offset? position,
  FlyoutPlacement placement = FlyoutPlacement.bottomStart,
  double gap = Space.xs,
  bool barrierDismissible = true,
}) {
  final motion = Motion.of(context);
  Rect anchorRect;
  final overlay =
      Navigator.of(context, rootNavigator: true).overlay!.context.findRenderObject() as RenderBox;
  if (position != null) {
    anchorRect = Rect.fromLTWH(position.dx, position.dy, 0, 0);
  } else {
    final box = (anchor ?? context).findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    anchorRect = topLeft & box.size;
  }
  return Navigator.of(context, rootNavigator: true).push<T>(
    _FlyoutRoute<T>(
      builder: builder,
      anchorRect: anchorRect,
      placement: placement,
      gap: gap,
      motion: motion,
      dismissible: barrierDismissible,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context, rootNavigator: true).context,
      ),
    ),
  );
}

class _FlyoutRoute<T> extends PopupRoute<T> {
  _FlyoutRoute({
    required this.builder,
    required this.anchorRect,
    required this.placement,
    required this.gap,
    required this.motion,
    required this.dismissible,
    required this.capturedThemes,
  });

  final WidgetBuilder builder;
  final Rect anchorRect;
  final FlyoutPlacement placement;
  final double gap;
  final Motion motion;
  final bool dismissible;
  final CapturedThemes capturedThemes;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => motion.d(const Duration(milliseconds: 180));

  @override
  Duration get reverseTransitionDuration => motion.d(const Duration(milliseconds: 100));

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final padding = MediaQuery.paddingOf(context);
    return SafeArea(
      child: CustomSingleChildLayout(
        delegate: _FlyoutLayout(anchorRect, placement, gap, padding),
        child: capturedThemes.wrap(FocusScope(autofocus: true, child: Builder(builder: builder))),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.standard,
      reverseCurve: Motion.exit,
    );
    final fromTop = placement == FlyoutPlacement.topStart || placement == FlyoutPlacement.topEnd;
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (fromTop ? 8 : -8) * (1 - curved.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

class _FlyoutLayout extends SingleChildLayoutDelegate {
  _FlyoutLayout(this.anchor, this.placement, this.gap, this.padding);

  final Rect anchor;
  final FlyoutPlacement placement;
  final double gap;
  final EdgeInsets padding;

  static const double margin = Space.s;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
    maxWidth: math.max(0, constraints.maxWidth - margin * 2),
    maxHeight: math.max(0, constraints.maxHeight - margin * 2),
  );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double x;
    double y;
    switch (placement) {
      case FlyoutPlacement.bottomStart:
      case FlyoutPlacement.bottomCenter:
      case FlyoutPlacement.bottomEnd:
        y = anchor.bottom + gap;
        if (y + childSize.height > size.height - margin &&
            anchor.top - gap - childSize.height >= margin) {
          y = anchor.top - gap - childSize.height;
        }
        x = switch (placement) {
          FlyoutPlacement.bottomEnd => anchor.right - childSize.width,
          FlyoutPlacement.bottomCenter => anchor.center.dx - childSize.width / 2,
          _ => anchor.left,
        };
      case FlyoutPlacement.topStart:
      case FlyoutPlacement.topEnd:
        y = anchor.top - gap - childSize.height;
        if (y < margin && anchor.bottom + gap + childSize.height <= size.height - margin) {
          y = anchor.bottom + gap;
        }
        x = placement == FlyoutPlacement.topEnd ? anchor.right - childSize.width : anchor.left;
      case FlyoutPlacement.rightStart:
        x = anchor.right + gap;
        if (x + childSize.width > size.width - margin) x = anchor.left - gap - childSize.width;
        y = anchor.top;
      case FlyoutPlacement.leftStart:
        x = anchor.left - gap - childSize.width;
        if (x < margin) x = anchor.right + gap;
        y = anchor.top;
    }
    x = x.clamp(margin, math.max(margin, size.width - childSize.width - margin));
    y = y.clamp(margin, math.max(margin, size.height - childSize.height - margin));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_FlyoutLayout old) =>
      old.anchor != anchor ||
      old.placement != placement ||
      old.gap != gap ||
      old.padding != padding;
}

// -----------------------------------------------------------------------------
// Context menu

/// Base of everything that can go in a menu.
sealed class MenuEntry {
  const MenuEntry();
}

class MenuDivider extends MenuEntry {
  const MenuDivider();
}

/// Non-interactive caption between groups.
class MenuHeader extends MenuEntry {
  const MenuHeader(this.label);

  final String label;
}

class MenuItem extends MenuEntry {
  const MenuItem({
    required this.label,
    this.icon,
    this.shortcut,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
    this.checked,
    this.trailing,
  });

  final String label;
  final IconData? icon;

  /// Right-aligned hint, e.g. `Ctrl+C`.
  final String? shortcut;
  final VoidCallback? onTap;
  final bool enabled;

  /// Red label (delete).
  final bool destructive;

  /// Shows a check mark when true (radio/option lists).
  final bool? checked;
  final Widget? trailing;
}

/// Menu list rendered inside a [FlyoutSurface].
class ContextMenu extends StatelessWidget {
  const ContextMenu({super.key, required this.items, this.width, this.minWidth = 180});

  final List<MenuEntry> items;
  final double? width;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final hasIcons = items.any((e) => e is MenuItem && (e.icon != null || e.checked != null));
    var firstFocusable = true;
    return FlyoutSurface(
      width: width,
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: 360),
      child: FocusTraversalGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in items)
              switch (e) {
                MenuDivider() => Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs, horizontal: Space.xs),
                  child: Divider(height: 1, color: colors.divider),
                ),
                MenuHeader(:final label) => Padding(
                  padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.xs),
                  child: Text(label, style: text.caption.copyWith(color: colors.textTertiary)),
                ),
                MenuItem() => Builder(
                  builder: (context) {
                    final autofocus = firstFocusable && e.enabled;
                    if (autofocus) firstFocusable = false;
                    return _MenuRow(item: e, reserveIconColumn: hasIcons, autofocus: autofocus);
                  },
                ),
              },
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.reserveIconColumn, required this.autofocus});

  final MenuItem item;
  final bool reserveIconColumn;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final enabled = item.enabled && item.onTap != null;
    final fg = !item.enabled
        ? colors.textDisabled
        : item.destructive
        ? colors.critical
        : colors.textPrimary;
    IconData? leading = item.icon;
    if (item.checked == true) leading = FluentIcons.checkmark_16_regular;
    return Pressable(
      onTap: enabled
          ? () {
              Navigator.of(context).pop();
              item.onTap!();
            }
          : null,
      enabled: item.enabled,
      autofocus: autofocus,
      semanticLabel: item.label,
      scaleOnPress: false,
      child: SizedBox(
        height: 32,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.m),
          child: Row(
            children: [
              if (reserveIconColumn)
                SizedBox(
                  width: 16 + Space.m,
                  child: leading == null ? null : Icon(leading, size: 16, color: fg),
                ),
              Expanded(
                child: Text(
                  item.label,
                  style: text.body.copyWith(color: fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.shortcut != null)
                Padding(
                  padding: const EdgeInsets.only(left: Space.xl),
                  child: Text(
                    item.shortcut!,
                    style: text.caption.copyWith(color: colors.textTertiary),
                  ),
                ),
              if (item.trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: Space.s),
                  child: item.trailing,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a [ContextMenu] at [position] (global coordinates).
Future<void> showContextMenu(
  BuildContext context, {
  required Offset position,
  required List<MenuEntry> items,
  double? width,
}) => showFlyout<void>(
  context,
  position: position,
  gap: 0,
  builder: (_) => ContextMenu(items: items, width: width),
);

/// Right click (desktop) or long press (touch) opens a [ContextMenu].
class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({
    super.key,
    required this.items,
    required this.child,
    this.enabled = true,
  });

  /// Built when the menu opens so the entries reflect current state.
  final List<MenuEntry> Function(BuildContext context) items;
  final Widget child;
  final bool enabled;

  static bool get _touch =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  void _open(BuildContext context, Offset position) {
    final entries = items(context);
    if (entries.isEmpty) return;
    showContextMenu(context, position: position, items: entries);
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (d) => _open(context, d.globalPosition),
      onLongPressStart: _touch ? (d) => _open(context, d.globalPosition) : null,
      child: child,
    );
  }
}
