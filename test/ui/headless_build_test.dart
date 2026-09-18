import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/app/shell/bottom_nav.dart';

import 'app_shell_test.dart' show pumpShell;

/// On Android the engine can start behind the foreground service, with no
/// window at all (process restarted by the system, reboot): the app then
/// builds and lays out in a 0x0 view until the user opens it, and must not
/// choke on that. When the window arrives the shell lays out again as usual.
void main() {
  testWidgets('the shell builds in a 0x0 view and recovers when a window arrives', (tester) async {
    await pumpShell(tester, Size.zero, settle: false);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomNav), findsOneWidget);
  });
}
