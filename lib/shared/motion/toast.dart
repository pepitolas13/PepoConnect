import 'dart:collection';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion.dart';
import 'pressable.dart';

enum ToastSeverity { info, success, caution, critical }

enum ToastPosition { bottomRight, top }

/// Inline action shown under the toast text.
@immutable
class ToastAction {
  const ToastAction({required this.label, required this.onPressed, this.closes = true});

  final String label;
  final VoidCallback onPressed;

  /// Dismiss the toast after running the action.
  final bool closes;
}

/// What a toast shows. Immutable; build it and hand it to [ToastService.show].
@immutable
class ToastData {
  const ToastData({
    required this.title,
    this.message,
    this.detail,
    this.severity = ToastSeverity.info,
    this.icon,
    this.thumbnail,
    this.actions = const [],
    this.duration = const Duration(seconds: 6),
    this.onTap,
    this.dismissible = true,
  });

  final String title;

  /// Second line (file name, device…).
  final String? message;

  /// Third, tertiary line (size, time…).
  final String? detail;
  final ToastSeverity severity;

  /// Overrides the severity icon.
  final IconData? icon;

  /// 40×40 thumbnail shown instead of the icon (transfers, new photos).
  final Widget? thumbnail;
  final List<ToastAction> actions;

  /// Zero keeps the toast until dismissed.
  final Duration duration;
  final VoidCallback? onTap;
  final bool dismissible;
}

/// One live toast.
class ToastEntry {
  ToastEntry._(this.id, this.data);

  final int id;
  final ToastData data;
  bool exiting = false;
}

/// Handle returned by [ToastService.show].
class ToastHandle {
  ToastHandle._(this._service, this._entry);

  final ToastService _service;
  final ToastEntry _entry;

  bool get isVisible => _service._visible.contains(_entry) && !_entry.exiting;

  void dismiss() => _service.dismiss(_entry);
}

/// Queue of toasts. At most [maxVisible] on screen; the rest wait.
class ToastService extends ChangeNotifier {
  ToastService({this.maxVisible = 3});

  final int maxVisible;
  final List<ToastEntry> _visible = [];
  final Queue<ToastEntry> _queue = Queue();
  int _nextId = 0;

  UnmodifiableListView<ToastEntry> get visible => UnmodifiableListView(_visible);
  int get pending => _queue.length;

  ToastHandle show(ToastData data) {
    final entry = ToastEntry._(_nextId++, data);
    if (_visible.where((e) => !e.exiting).length < maxVisible) {
      _visible.add(entry);
    } else {
      _queue.add(entry);
    }
    notifyListeners();
    return ToastHandle._(this, entry);
  }

  ToastHandle info(String title, {String? message, List<ToastAction> actions = const []}) =>
      show(ToastData(title: title, message: message, actions: actions));

  ToastHandle success(String title, {String? message, List<ToastAction> actions = const []}) =>
      show(
        ToastData(
          title: title,
          message: message,
          severity: ToastSeverity.success,
          actions: actions,
        ),
      );

  ToastHandle caution(String title, {String? message, List<ToastAction> actions = const []}) =>
      show(
        ToastData(
          title: title,
          message: message,
          severity: ToastSeverity.caution,
          actions: actions,
        ),
      );

  ToastHandle error(String title, {String? message, List<ToastAction> actions = const []}) => show(
    ToastData(
      title: title,
      message: message,
      severity: ToastSeverity.critical,
      duration: const Duration(seconds: 10),
      actions: actions,
    ),
  );

  /// Starts the exit animation; [_remove] runs once it finished.
  void dismiss(ToastEntry entry) {
    if (!_visible.contains(entry) || entry.exiting) {
      _queue.remove(entry);
      return;
    }
    entry.exiting = true;
    notifyListeners();
  }

  void dismissAll() {
    _queue.clear();
    for (final e in _visible) {
      e.exiting = true;
    }
    notifyListeners();
  }

  void _remove(ToastEntry entry) {
    _visible.remove(entry);
    while (_queue.isNotEmpty && _visible.where((e) => !e.exiting).length < maxVisible) {
      _visible.add(_queue.removeFirst());
    }
    notifyListeners();
  }

  static ToastService of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No ToastHost above this context');
    return scope!;
  }

  static ToastService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ToastScope>()?.service;
}

class _ToastScope extends InheritedWidget {
  const _ToastScope({required this.service, required super.child});

  final ToastService service;

  @override
  bool updateShouldNotify(_ToastScope oldWidget) => oldWidget.service != service;
}

/// Renders the toasts of a [ToastService] above [child]. Put it once in
/// `MaterialApp.builder`. Desktop: bottom-right, 360 px. Mobile: top.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.service, required this.child, this.position});

  final ToastService service;
  final Widget child;

  /// Defaults to top on Android/iOS, bottom-right elsewhere.
  final ToastPosition? position;

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  final OverlayPortalController _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(ToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service.removeListener(_sync);
      widget.service.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.service.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final shouldShow = widget.service._visible.isNotEmpty;
    if (shouldShow && !_portal.isShowing) {
      _portal.show();
    } else if (!shouldShow && _portal.isShowing) {
      _portal.hide();
    }
  }

  ToastPosition get _position =>
      widget.position ??
      (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS
          ? ToastPosition.top
          : ToastPosition.bottomRight);

  @override
  Widget build(BuildContext context) {
    return _ToastScope(
      service: widget.service,
      child: Overlay.wrap(
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) =>
              _ToastLayer(service: widget.service, position: _position),
          child: widget.child,
        ),
      ),
    );
  }
}

class _ToastLayer extends StatelessWidget {
  const _ToastLayer({required this.service, required this.position});

  final ToastService service;
  final ToastPosition position;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final top = position == ToastPosition.top;
    final toastWidth = top ? (width - Space.l * 2).clamp(200.0, 480.0) : Sizes.toastWidth;
    return Positioned(
      right: top ? null : Space.l + padding.right,
      bottom: top ? null : Space.l + padding.bottom,
      top: top ? padding.top + Space.s : null,
      left: top ? (width - toastWidth) / 2 : null,
      width: toastWidth,
      child: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final entries = service.visible.toList();
          final ordered = top ? entries.reversed.toList() : entries;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in ordered)
                Padding(
                  key: ValueKey(e.id),
                  padding: EdgeInsets.only(top: top ? 0 : Space.s, bottom: top ? Space.s : 0),
                  child: _ToastCard(
                    entry: e,
                    fromTop: top,
                    onDismiss: () => service.dismiss(e),
                    onGone: () => service._remove(e),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.entry,
    required this.fromTop,
    required this.onDismiss,
    required this.onGone,
  });

  final ToastEntry entry;
  final bool fromTop;
  final VoidCallback onDismiss;
  final VoidCallback onGone;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this);
  late final AnimationController _life = AnimationController(vsync: this);
  bool _exiting = false;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _life.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDismiss();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_enter.value == 0 && !_enter.isAnimating) {
      final motion = Motion.of(context);
      _enter.animateTo(1, duration: motion.normal, curve: Motion.standard);
      final life = widget.entry.data.duration;
      if (life > Duration.zero) {
        _life.duration = life;
        _life.forward();
      }
    }
    _syncExit();
  }

  @override
  void didUpdateWidget(_ToastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncExit();
  }

  Future<void> _syncExit() async {
    if (!widget.entry.exiting || _exiting) return;
    _exiting = true;
    _life.stop();
    final motion = Motion.of(context);
    await _enter.animateTo(0, duration: motion.ms(150), curve: Motion.exit);
    if (mounted) widget.onGone();
  }

  void _setHover(bool v) {
    if (_hovering == v) return;
    _hovering = v;
    if (_life.duration == null || _exiting) return;
    if (v) {
      _life.stop();
    } else {
      _life.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _life.dispose();
    super.dispose();
  }

  IconData _iconFor(ToastSeverity s) => switch (s) {
    ToastSeverity.info => FluentIcons.info_20_regular,
    ToastSeverity.success => FluentIcons.checkmark_circle_20_filled,
    ToastSeverity.caution => FluentIcons.warning_20_filled,
    ToastSeverity.critical => FluentIcons.error_circle_20_filled,
  };

  Color _colorFor(PepoColors c, ToastSeverity s) => switch (s) {
    ToastSeverity.info => c.accent,
    ToastSeverity.success => c.success,
    ToastSeverity.caution => c.caution,
    ToastSeverity.critical => c.critical,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final data = widget.entry.data;
    final tint = _colorFor(colors, data.severity);

    Widget leading;
    if (data.thumbnail != null) {
      leading = ClipRRect(
        borderRadius: Radii.controlRadius,
        child: SizedBox.square(dimension: 40, child: data.thumbnail),
      );
    } else {
      leading = Icon(data.icon ?? _iconFor(data.severity), size: 20, color: tint);
    }

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.flyoutSurface,
        borderRadius: Radii.cardRadius,
        border: Border.all(color: colors.cardStroke),
        boxShadow: PepoShadows.toast,
      ),
      child: ClipRRect(
        borderRadius: Radii.cardRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.m, Space.m, Space.s, Space.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: leading),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: text.bodyStrong,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (data.message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              data.message!,
                              style: text.body.copyWith(color: colors.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (data.detail != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              data.detail!,
                              style: text.caption.copyWith(color: colors.textTertiary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (data.actions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.s),
                            child: Wrap(
                              spacing: Space.s,
                              children: [
                                for (final a in data.actions)
                                  _ToastActionButton(
                                    label: a.label,
                                    onPressed: () {
                                      a.onPressed();
                                      if (a.closes) widget.onDismiss();
                                    },
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (data.dismissible)
                    Pressable(
                      onTap: widget.onDismiss,
                      semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
                      child: const SizedBox.square(
                        dimension: 28,
                        child: Icon(FluentIcons.dismiss_16_regular, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            if (_life.duration != null)
              AnimatedBuilder(
                animation: _life,
                builder: (context, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 1 - _life.value,
                    child: Container(height: 2, color: tint.withValues(alpha: 0.6)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // The overlay sits outside any Scaffold: Material gives text its style.
    final interactive = Material(
      type: MaterialType.transparency,
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: data.onTap == null
            ? card
            : Pressable(
                onTap: () {
                  data.onTap!();
                  widget.onDismiss();
                },
                borderRadius: Radii.cardRadius,
                showHoverFill: false,
                child: card,
              ),
      ),
    );

    return AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final t = _enter.value;
        final offset = widget.fromTop ? Offset(0, -16 * (1 - t)) : Offset(16 * (1 - t), 0);
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(offset: offset, child: child),
        );
      },
      child: RepaintBoundary(child: interactive),
    );
  }
}

class _ToastActionButton extends StatelessWidget {
  const _ToastActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    return Pressable(
      onTap: onPressed,
      builder: (context, states, _) => Padding(
        // No alignment here: inside a Wrap the button must hug its label.
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
        child: Text(
          label,
          style: context.text.bodyStrong.copyWith(
            color: states.pressed ? colors.accentPressed : colors.accent,
          ),
        ),
      ),
    );
  }
}
