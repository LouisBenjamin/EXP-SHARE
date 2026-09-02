import 'package:tally/core/theme.dart';
import 'package:tally/features/expenses/providers/categories_provider.dart';
import 'package:tally/features/import/providers/import_providers.dart';
import 'package:tally/features/labels/ui/labels_tab.dart';
import 'package:tally/models/category.dart';
import 'package:tally/models/merchant_rule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../support/test_supabase.dart';

const _gid = 'g1';

const _categories = [
  Category(id: 'global1', name: 'Groceries', icon: 'shopping-cart'),
  Category(id: 'group1', name: 'Coffee', icon: 'coffee', groupId: _gid),
];

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
}

Widget _host(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: LabelsTab(groupId: _gid)),
      ),
    );

void main() {
  setUpAll(initTestSupabase);

  testWidgets('renders both a categories and a tags section', (tester) async {
    _desktop(tester);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host([
      categoriesProvider(_gid).overrideWith((ref) async => _categories),
      merchantRulesProvider(_gid).overrideWith((ref) async => [
            const MerchantRule(
              id: 'r1',
              groupId: _gid,
              pattern: 'COSTCO',
              matchType: 'contains',
              action: 'share',
              priority: 100,
              categoryId: 'global1',
            ),
          ]),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('COSTCO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a global category shows a Default chip and no delete button',
      (tester) async {
    _desktop(tester);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host([
      categoriesProvider(_gid).overrideWith((ref) async => _categories),
      merchantRulesProvider(_gid).overrideWith((ref) async => []),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Default'), findsOneWidget);
    // Two categories, one delete button — the global row has none.
    expect(find.byIcon(PhosphorIconsRegular.trash), findsOneWidget);
  });

  testWidgets('empty states appear with no categories or tags',
      (tester) async {
    _desktop(tester);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host([
      categoriesProvider(_gid).overrideWith((ref) async => const []),
      merchantRulesProvider(_gid).overrideWith((ref) async => []),
    ]));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No categories yet'),
      findsOneWidget,
    );
    expect(find.text('No tags yet.'), findsOneWidget);
  });

  testWidgets('deleting a group category opens a confirm dialog',
      (tester) async {
    _desktop(tester);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host([
      categoriesProvider(_gid).overrideWith((ref) async => _categories),
      merchantRulesProvider(_gid).overrideWith((ref) async => []),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIconsRegular.trash));
    await tester.pumpAndSettle();

    expect(find.text('Delete category?'), findsOneWidget);
    expect(find.textContaining('Coffee'), findsWidgets);
  });
}
