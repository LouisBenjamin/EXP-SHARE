import 'package:tally/core/widgets/page_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Documents the contract: phones are untouched, desktop content is capped.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PageBody(
            child: SizedBox.expand(child: Placeholder(key: Key('content'))),
          ),
        ),
      ),
    );
  }

  testWidgets('on a phone the body still fills the width', (tester) async {
    await pumpAt(tester, const Size(400, 800));
    expect(tester.getSize(find.byKey(const Key('content'))).width, 400);
  });

  testWidgets('on a wide window the body is capped', (tester) async {
    await pumpAt(tester, const Size(1600, 900));
    expect(
      tester.getSize(find.byKey(const Key('content'))).width,
      kContentMaxWidth,
    );
  });
}
