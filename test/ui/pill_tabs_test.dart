import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/shared/widgets/pill_tabs.dart';

import 'harness.dart';

void main() {
  testWidgets('renders every tab and reports taps', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(
      harness(
        child: PillTabs(tabs: const ['Fotos', 'Vídeos', 'Todo'], index: 0, onChanged: taps.add),
      ),
    );
    expect(find.text('Fotos'), findsOneWidget);
    expect(find.text('Vídeos'), findsOneWidget);
    expect(find.text('Todo'), findsOneWidget);
    expect(tester.getSize(find.byType(PillTabs)).height, 32);

    await tester.tap(find.text('Vídeos'));
    await tester.pumpAndSettle();
    expect(taps, [1]);

    await tester.tap(find.text('Todo'));
    await tester.pumpAndSettle();
    expect(taps, [1, 2]);
  });

  testWidgets('pills share the width of the widest label', (tester) async {
    await tester.pumpWidget(
      harness(
        child: PillTabs(tabs: const ['A', 'Un texto largo', 'B'], index: 1, onChanged: (_) {}),
      ),
    );
    final a = tester.getSize(find.ancestor(of: find.text('A'), matching: find.byType(Expanded)));
    final b = tester.getSize(find.ancestor(of: find.text('B'), matching: find.byType(Expanded)));
    final long = tester.getSize(
      find.ancestor(of: find.text('Un texto largo'), matching: find.byType(Expanded)),
    );
    expect(a.width, closeTo(long.width, 0.01));
    expect(b.width, closeTo(long.width, 0.01));
  });
}
