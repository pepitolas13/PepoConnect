import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/shared/motion/motion.dart';
import 'package:pepoconnect/shared/motion/motion_scope.dart';

void main() {
  test('Motion.off has zero durations and no geometry change', () {
    const off = Motion.off();
    expect(off.enabled, isFalse);
    expect(off.fast, Duration.zero);
    expect(off.normal, Duration.zero);
    expect(off.slow, Duration.zero);
    expect(off.page, Duration.zero);
    expect(off.glow, Duration.zero);
    expect(off.d(const Duration(seconds: 3)), Duration.zero);
    expect(off.ms(260), Duration.zero);
    expect(off.pressScale, 1.0);
    expect(off.hoverLight, isFalse);
  });

  test('Motion.on has the documented durations', () {
    const on = Motion.on();
    expect(on.enabled, isTrue);
    expect(on.fast, const Duration(milliseconds: 100));
    expect(on.normal, const Duration(milliseconds: 200));
    expect(on.slow, const Duration(milliseconds: 300));
    expect(on.page, const Duration(milliseconds: 180));
    expect(on.glow, const Duration(milliseconds: 1500));
    expect(on.d(const Duration(milliseconds: 260)), const Duration(milliseconds: 260));
    expect(on.pressScale, 0.97);
    expect(Motion.spring, const Cubic(0.22, 1.2, 0.36, 1.0));
    expect(Motion.standard, Curves.easeOutCubic);
    expect(Motion.emphasized, Curves.easeInOutCubicEmphasized);
    expect(Motion.exit, Curves.easeInCubic);
  });

  testWidgets('MotionScope combines the setting with disableAnimations', (tester) async {
    Motion? seen;
    Widget probe() => Builder(
      builder: (context) {
        seen = Motion.of(context);
        return const SizedBox();
      },
    );

    await tester.pumpWidget(MotionScope(enabled: true, child: probe()));
    expect(seen!.enabled, isTrue);

    await tester.pumpWidget(MotionScope(enabled: false, child: probe()));
    expect(seen!.enabled, isFalse);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MotionScope(enabled: true, child: probe()),
      ),
    );
    expect(seen!.enabled, isFalse);

    // Outside a scope the platform flag still counts.
    await tester.pumpWidget(
      MediaQuery(data: const MediaQueryData(disableAnimations: true), child: probe()),
    );
    expect(seen!.enabled, isFalse);
    await tester.pumpWidget(probe());
    expect(seen!.enabled, isTrue);
  });
}
