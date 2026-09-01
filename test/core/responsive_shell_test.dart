import 'package:exp_share/core/widgets/responsive_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Documents the breakpoint: mobile must stay untouched, desktop must clamp.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveShell(
          child: SizedBox.expand(child: Placeholder(key: Key('content'))),
        ),
      ),
    );
  }

  testWidgets('below the breakpoint the child fills the width', (tester) async {
    await pumpAt(tester, const Size(400, 800));
    expect(tester.getSize(find.byKey(const Key('content'))).width, 400);
  });

  testWidgets('above the breakpoint the child is clamped', (tester) async {
    await pumpAt(tester, const Size(1400, 900));
    expect(tester.getSize(find.byKey(const Key('content'))).width, 560);
  });
}
