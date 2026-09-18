import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'motion.dart';

/// Container for the branch Navigators of a [StatefulShellRoute]: a dissolve
/// between sections instead of the instant swap of an [IndexedStack].
///
/// The new section fades in on top (ease-out, rising [slide] px) from the
/// very first frame, while the section being left stays painted underneath
/// and dims linearly, so the content layer never shows bare: what shows
/// through both is at most (1 - t)³ · t, under 11 % and only around 45 ms
/// in. Ease-out on top of linear puts the crossover a third of the way in
/// (about 60 ms), so the new section reads at once and the old one is a short
/// tail rather than a double exposure. Every branch keeps its Navigator and state: the ones
/// not involved are offstage with their tickers muted, exactly as in
/// [StatefulShellRoute.indexedStack].
class BranchCrossFade extends StatefulWidget {
  const BranchCrossFade({
    super.key,
    required this.currentIndex,
    required this.children,
    this.slide = 8,
  });

  /// Drop-in [ShellNavigationContainerBuilder].
  static Widget builder(
    BuildContext context,
    StatefulNavigationShell shell,
    List<Widget> children,
  ) => BranchCrossFade(currentIndex: shell.currentIndex, children: children);

  final int currentIndex;

  /// One Navigator per branch, in branch order.
  final List<Widget> children;

  /// Rise of the incoming section, in logical pixels.
  final double slide;

  @override
  State<BranchCrossFade> createState() => _BranchCrossFadeState();
}

class _BranchCrossFadeState extends State<BranchCrossFade> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1)
    ..addStatusListener(_onStatus);

  /// Incoming: ease-out, fast at the start.
  late final Animation<double> _enter = CurvedAnimation(
    parent: _controller,
    curve: Motion.standard,
  );

  /// Outgoing: a linear dim, so it is a tail under the new section rather
  /// than a double exposure.
  late final Animation<double> _leave = ReverseAnimation(_controller);

  /// Branch on its way out, while the dissolve runs.
  int? _leaving;

  void _onStatus(AnimationStatus status) {
    if (status.isCompleted && _leaving != null && mounted) {
      setState(() => _leaving = null);
    }
  }

  @override
  void didUpdateWidget(BranchCrossFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    final motion = Motion.of(context);
    if (!motion.enabled) {
      _leaving = null;
      _controller.value = 1;
      return;
    }
    // A switch in the middle of a dissolve: the half-shown section becomes
    // the one leaving; the one it was covering is dropped at once.
    _leaving = oldWidget.currentIndex;
    _controller
      ..stop()
      ..value = 0
      ..animateTo(1, duration: motion.page, curve: Curves.linear);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.currentIndex;
    final leaving = _leaving;
    // Paint order: idle branches (offstage), the one leaving, the current one
    // on top. Keys keep every Navigator's element in place across reorders.
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (i != current && i != leaving) _branch(i, _BranchRole.idle),
        if (leaving != null) _branch(leaving, _BranchRole.leaving),
        _branch(current, _BranchRole.current),
      ],
    );
  }

  /// The same wrapper chain for every role, so a branch changing role never
  /// changes element types (only their parameters).
  Widget _branch(int index, _BranchRole role) {
    final active = role == _BranchRole.current;
    final opacity = switch (role) {
      _BranchRole.current => _enter,
      _BranchRole.leaving => _leave,
      _BranchRole.idle => kAlwaysCompleteAnimation,
    };
    return KeyedSubtree(
      key: branchSlotKey(index),
      child: Offstage(
        offstage: role == _BranchRole.idle,
        child: TickerMode(
          enabled: active,
          child: IgnorePointer(
            ignoring: !active,
            child: ExcludeSemantics(
              excluding: !active,
              child: FadeTransition(
                opacity: opacity,
                child: AnimatedBuilder(
                  animation: active ? _enter : kAlwaysCompleteAnimation,
                  builder: (context, child) => Transform.translate(
                    offset: active ? Offset(0, widget.slide * (1 - _enter.value)) : Offset.zero,
                    child: child,
                  ),
                  child: widget.children[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _BranchRole { current, leaving, idle }

/// Key of the wrapper around branch [index] in a [BranchCrossFade].
@visibleForTesting
Key branchSlotKey(int index) => ValueKey<String>('branch-slot-$index');
