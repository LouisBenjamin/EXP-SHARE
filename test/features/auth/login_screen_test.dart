import 'package:tally/core/theme.dart';
import 'package:tally/features/auth/ui/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('email step renders the branding and the send button',
      (tester) async {
    await pump(tester, const Size(1200, 900));
    expect(find.text('Tally'), findsOneWidget);
    expect(find.text('Split expenses simply.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget); // the field's label
    expect(find.widgetWithText(FilledButton, 'Send login code'),
        findsOneWidget);
  });

  testWidgets('the code step is not shown before a code is requested',
      (tester) async {
    await pump(tester, const Size(1200, 900));
    expect(find.textContaining('digit code'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Verify & log in'), findsNothing);
  });

  testWidgets('tapping send with an empty email does nothing', (tester) async {
    await pump(tester, const Size(1200, 900));
    await tester.tap(find.widgetWithText(FilledButton, 'Send login code'));
    await tester.pump();
    // still on the email step, no crash, no navigation
    expect(find.widgetWithText(FilledButton, 'Send login code'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login card is width-capped on a very wide window',
      (tester) async {
    await pump(tester, const Size(2400, 1000));
    final box = tester.widget<ConstrainedBox>(
      find
          .ancestor(
            of: find.text('Tally'),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(box.constraints.maxWidth, lessThanOrEqualTo(420));
  });
}
