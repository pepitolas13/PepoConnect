import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/shared/theme/tokens.dart';
import 'package:pepoconnect/shared/widgets/thin_progress_bar.dart';

import 'harness.dart';

void main() {
  testWidgets('is 4 px tall and collapses after completing', (tester) async {
    await tester.pumpWidget(
      harness(child: const SizedBox(width: 200, child: ThinProgressBar(value: 0.5))),
    );
    expect(tester.getSize(find.byType(ThinProgressBar)).height, Sizes.progressBar);

    await tester.pumpWidget(
      harness(child: const SizedBox(width: 200, child: ThinProgressBar(value: 1))),
    );
    await tester.pump();
    // Still visible (green) during the pause…
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(find.byType(ThinProgressBar)).height, Sizes.progressBar);
    // …then collapsed.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(find.byType(ThinProgressBar)).height, 0);
  });

  testWidgets('does not collapse when asked not to', (tester) async {
    await tester.pumpWidget(
      harness(
        child: const SizedBox(
          width: 200,
          child: ThinProgressBar(value: 1, collapseOnComplete: false),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getSize(find.byType(ThinProgressBar)).height, Sizes.progressBar);
  });

  testWidgets('collapses instantly with motion off', (tester) async {
    await tester.pumpWidget(
      harness(
        animations: false,
        child: const SizedBox(width: 200, child: ThinProgressBar(value: 1)),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(find.byType(ThinProgressBar)).height, 0);
  });

  testWidgets('indeterminate bar renders without a value', (tester) async {
    await tester.pumpWidget(
      harness(child: const SizedBox(width: 200, child: ThinProgressBar(value: null))),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.getSize(find.byType(ThinProgressBar)).height, Sizes.progressBar);
  });
}
