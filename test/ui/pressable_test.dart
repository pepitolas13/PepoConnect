import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/shared/motion/pressable.dart';

import 'harness.dart';

double _scaleOf(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(of: find.byType(Pressable), matching: find.byType(Transform)).first,
  );
  // X-axis scale (the z-axis is always 1, so getMaxScaleOnAxis would lie).
  return transform.transform.entry(0, 0);
}

void main() {
  testWidgets('scales down while pressed and springs back (motion on)', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      harness(
        child: Pressable(onTap: () => taps++, child: const SizedBox(width: 80, height: 40)),
      ),
    );
    expect(_scaleOf(tester), 1.0);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_scaleOf(tester), lessThan(1.0));
    expect(_scaleOf(tester), greaterThan(0.96));

    await gesture.up();
    await tester.pump();
    expect(taps, 1);
    await tester.pumpAndSettle();
    expect(_scaleOf(tester), closeTo(1.0, 0.0001));
  });

  testWidgets('does not animate nor scale with motion off', (tester) async {
    PressableStates? seen;
    await tester.pumpWidget(
      harness(
        animations: false,
        child: Pressable(
          onTap: () {},
          builder: (context, states, _) {
            seen = states;
            return const SizedBox(width: 80, height: 40);
          },
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    // Colour state switches instantly, geometry stays put and nothing keeps
    // scheduling frames.
    expect(seen!.pressed, isTrue);
    expect(_scaleOf(tester), 1.0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await gesture.up();
    await tester.pump();
    expect(seen!.pressed, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reports hover for mouse pointers', (tester) async {
    PressableStates? seen;
    await tester.pumpWidget(
      harness(
        child: Pressable(
          onTap: () {},
          builder: (context, states, _) {
            seen = states;
            return const SizedBox(width: 80, height: 40);
          },
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();
    expect(seen!.hovered, isFalse);

    await mouse.moveTo(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    expect(seen!.hovered, isTrue);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(seen!.hovered, isFalse);
  });

  testWidgets('keyboard focus shows the ring and Enter activates', (tester) async {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    var taps = 0;
    PressableStates? seen;
    await tester.pumpWidget(
      harness(
        child: Pressable(
          autofocus: true,
          onTap: () => taps++,
          builder: (context, states, _) {
            seen = states;
            return const SizedBox(width: 80, height: 40);
          },
        ),
      ),
    );
    await tester.pump();
    // Focused by autofocus, but no key has been pressed yet: no ring.
    expect(seen!.focused, isFalse);

    // Any key press reveals the ring on the focused control.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(seen!.focused, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 2);
  });

  testWidgets('disabled without callbacks: no hover, not a tap target', (tester) async {
    PressableStates? seen;
    await tester.pumpWidget(
      harness(
        child: Pressable(
          builder: (context, states, _) {
            seen = states;
            return const SizedBox(width: 80, height: 40);
          },
        ),
      ),
    );
    expect(seen!.enabled, isFalse);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    expect(seen!.hovered, isFalse);
  });
}
