import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'motion.dart';

/// Route transition used on every platform except iOS: a dissolve with an
/// 8 px rise, 200 ms in and 160 ms out. iOS keeps the Cupertino push.
class FluentPageTransitionsBuilder extends PageTransitionsBuilder {
  const FluentPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return fluentTransition(
      animation,
      secondaryAnimation,
      child,
      slide: route.fullscreenDialog ? 0 : 8,
    );
  }
}

/// The shared transition: a dissolve that never shows the window background.
///
/// The page that ends up on screen moves fast (ease-out) while the one that
/// ends up hidden goes slower, so at every frame one of the two is mostly
/// opaque and neither lingers long enough to read as a double exposure.
///
/// Push: this page fades in and rises [slide] px over the page below, which
/// stays put and dims linearly; what shows through both is at most
/// (1 - t)³ · t, under 11 % and only around a quarter of the way in. Pop:
/// the page below is back at once (1 - t³) and this page dissolves with a
/// symmetric ease-in-out, so the grid under the viewer is already there
/// while the photo flies home; under 8 % shows through. With motion off the
/// route duration is zero and the curves resolve to the end state on the
/// first frame. `transitions_test.dart` checks both bounds.
Widget fluentTransition(
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child, {
  double slide = 8,
}) {
  final fade = CurvedAnimation(
    parent: animation,
    curve: Motion.standard,
    reverseCurve: Curves.easeInOutCubic,
  );
  final rise = Tween<Offset>(begin: Offset(0, slide), end: Offset.zero).animate(fade);
  // secondaryAnimation: 0 → 1 while another route covers this one: a linear
  // dim on push, uncovered at once (ease-in of the reversing value) on pop.
  final covered = CurvedAnimation(
    parent: secondaryAnimation,
    curve: Curves.linear,
    reverseCurve: Motion.exit,
  );
  final hide = Tween<double>(begin: 1, end: 0).animate(covered);
  return FadeTransition(
    opacity: fade,
    child: FadeTransition(
      opacity: hide,
      child: slide == 0
          ? child
          : AnimatedBuilder(
              animation: rise,
              builder: (context, child) => Transform.translate(offset: rise.value, child: child),
              child: child,
            ),
    ),
  );
}

/// A [Page] for go_router routes that need the Fluent transition.
class FluentPage<T> extends Page<T> {
  const FluentPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    this.fullscreenDialog = false,
    this.opaque = true,
  });

  final Widget child;

  /// Full-screen dialogs (the viewer) dissolve in place, without the rise.
  final bool fullscreenDialog;
  final bool opaque;

  @override
  Route<T> createRoute(BuildContext context) => _FluentPageRoute<T>(this);
}

class _FluentPageRoute<T> extends PageRoute<T> {
  _FluentPageRoute(FluentPage<T> page)
    : super(settings: page, fullscreenDialog: page.fullscreenDialog);

  FluentPage<T> get _page => settings as FluentPage<T>;

  @override
  bool get opaque => _page.opaque;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration =>
      Motion.of(navigator!.context).d(const Duration(milliseconds: 200));

  @override
  Duration get reverseTransitionDuration =>
      Motion.of(navigator!.context).d(const Duration(milliseconds: 160));

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(scopesRoute: true, explicitChildNodes: true, child: _page.child);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return const CupertinoPageTransitionsBuilder().buildTransitions(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return fluentTransition(
      animation,
      secondaryAnimation,
      child,
      slide: fullscreenDialog ? 0 : 8,
    );
  }
}
