import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/shared/motion/fade_slide_switcher.dart';
import 'package:pepoconnect/shared/motion/fluent_page_transitions.dart';
import 'package:pepoconnect/shared/motion/motion_scope.dart';

/// A frozen animation with a direction, so curves pick the right branch.
class _At extends Animation<double> {
  const _At(this.value, this.status);

  @override
  final double value;

  @override
  final AnimationStatus status;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}
}

const _top = Key('top');
const _below = Key('below');

/// Effective opacity of the subtree under [root]: the product of every
/// FadeTransition on the way down.
double _opacity(WidgetTester tester, Key root) {
  var value = 1.0;
  final fades = find.descendant(of: find.byKey(root), matching: find.byType(FadeTransition));
  for (final fade in tester.widgetList<FadeTransition>(fades)) {
    value *= fade.opacity.value;
  }
  return value;
}

/// Two routes mid-transition: the one on top at [primary], the one below
/// covered by [secondary].
Future<void> _pumpPair(WidgetTester tester, Animation<double> primary, Animation<double> secondary) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          KeyedSubtree(
            key: _below,
            child: fluentTransition(
              const _At(1, AnimationStatus.completed),
              secondary,
              const SizedBox.expand(),
            ),
          ),
          KeyedSubtree(
            key: _top,
            child: fluentTransition(
              primary,
              const _At(0, AnimationStatus.dismissed),
              const SizedBox.expand(),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('fluentTransition', () {
    testWidgets('push: the page below stays under the new one, no gap', (tester) async {
      for (var i = 0; i <= 50; i++) {
        final t = i / 50;
        await _pumpPair(tester, _At(t, AnimationStatus.forward), _At(t, AnimationStatus.forward));
        final top = _opacity(tester, _top);
        final below = _opacity(tester, _below);
        // What shows through both pages.
        expect((1 - top) * (1 - below), lessThanOrEqualTo(0.11), reason: 't=$t');
        // The page below dims steadily: still half there halfway.
        expect(below, closeTo(1 - t, 0.001), reason: 't=$t');
      }
      // The new page answers at once: over half visible a quarter of the way in.
      await _pumpPair(
        tester,
        const _At(0.25, AnimationStatus.forward),
        const _At(0.25, AnimationStatus.forward),
      );
      expect(_opacity(tester, _top), greaterThan(0.5));
    });

    testWidgets('pop: the page below is back at once, the top one dissolves', (tester) async {
      for (var i = 0; i <= 50; i++) {
        final s = i / 50;
        await _pumpPair(tester, _At(s, AnimationStatus.reverse), _At(s, AnimationStatus.reverse));
        final top = _opacity(tester, _top);
        final below = _opacity(tester, _below);
        expect((1 - top) * (1 - below), lessThanOrEqualTo(0.08), reason: 's=$s');
      }
      // A quarter of the way into the pop the page below is over half back.
      await _pumpPair(
        tester,
        const _At(0.75, AnimationStatus.reverse),
        const _At(0.75, AnimationStatus.reverse),
      );
      expect(_opacity(tester, _below), greaterThan(0.5));
    });

    testWidgets('full-screen dialogs dissolve in place, other pages rise 8 px', (tester) async {
      Offset offsetOf() {
        final transform = tester.widget<Transform>(find.byType(Transform));
        return Offset(transform.transform.storage[12], transform.transform.storage[13]);
      }

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: fluentTransition(
            const _At(0, AnimationStatus.forward),
            const _At(0, AnimationStatus.dismissed),
            const SizedBox.expand(),
          ),
        ),
      );
      expect(offsetOf(), const Offset(0, 8));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: fluentTransition(
            const _At(0, AnimationStatus.forward),
            const _At(0, AnimationStatus.dismissed),
            const SizedBox.expand(),
            slide: 0,
          ),
        ),
      );
      expect(find.byType(Transform), findsNothing);
    });
  });

  group('FadeSlideSwitcher', () {
    const a = Key('a');
    const b = Key('b');

    Widget host(Widget child, {bool animations = true}) => Directionality(
      textDirection: TextDirection.ltr,
      child: MotionScope(
        enabled: animations,
        child: FadeSlideSwitcher(child: child),
      ),
    );

    double alpha(WidgetTester tester, Key key) => tester
        .widget<FadeTransition>(
          find.ancestor(of: find.byKey(key), matching: find.byType(FadeTransition)).first,
        )
        .opacity
        .value;

    testWidgets('the old child lingers under the new one and never leaves a gap', (tester) async {
      await tester.pumpWidget(host(const SizedBox(key: a)));
      await tester.pumpWidget(host(const SizedBox(key: b)));
      await tester.pump();
      expect(alpha(tester, a), 1);
      expect(alpha(tester, b), 0);

      for (var elapsed = 0; elapsed < 180; elapsed += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.byKey(a), findsOneWidget, reason: '$elapsed ms');
        expect(find.byKey(b), findsOneWidget, reason: '$elapsed ms');
        final gap = (1 - alpha(tester, a)) * (1 - alpha(tester, b));
        expect(gap, lessThanOrEqualTo(0.11), reason: '$elapsed ms');
      }
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(a), findsNothing);
      expect(alpha(tester, b), 1);
    });

    testWidgets('the old child does not move while it fades', (tester) async {
      await tester.pumpWidget(host(const SizedBox(key: a)));
      await tester.pumpWidget(host(const SizedBox(key: b)));
      await tester.pump(const Duration(milliseconds: 60));
      Offset offsetOf(Key key) {
        final transform = tester.widget<Transform>(
          find.ancestor(of: find.byKey(key), matching: find.byType(Transform)).first,
        );
        return Offset(transform.transform.storage[12], transform.transform.storage[13]);
      }

      expect(offsetOf(a), Offset.zero);
      expect(offsetOf(b).dy, greaterThan(0));
      expect(offsetOf(b).dy, lessThan(8));
    });

    testWidgets('with motion off the swap is instant', (tester) async {
      await tester.pumpWidget(host(const SizedBox(key: a), animations: false));
      await tester.pumpWidget(host(const SizedBox(key: b), animations: false));
      await tester.pump();
      expect(find.byKey(a), findsNothing);
      expect(alpha(tester, b), 1);
    });
  });
}
