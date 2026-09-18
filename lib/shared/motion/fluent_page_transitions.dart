import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'motion.dart';

/// Route transition used on every platform except iOS: fade + 8 px slide,
/// 200 ms in, quicker out. iOS keeps the Cupertino push.
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
    final motion = Motion.of(context);
    return fluentTransition(motion, animation, child);
  }
}

/// The shared transition. With motion off the curves still resolve to the
/// end state on the first frame because the route duration is zero.
Widget fluentTransition(Motion motion, Animation<double> animation, Widget child) {
  final fade = CurvedAnimation(
    parent: animation,
    curve: Motion.standard,
    reverseCurve: Motion.exit,
  );
  final slide = Tween<Offset>(begin: const Offset(0, 8), end: Offset.zero).animate(fade);
  return FadeTransition(
    opacity: fade,
    child: AnimatedBuilder(
      animation: slide,
      builder: (context, child) => Transform.translate(offset: slide.value, child: child),
      child: child,
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
      Motion.of(navigator!.context).d(const Duration(milliseconds: 120));

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
    return fluentTransition(Motion.of(context), animation, child);
  }
}
