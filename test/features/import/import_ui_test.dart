import 'package:decimal/decimal.dart';
import 'package:tally/core/theme.dart';
import 'package:tally/features/expenses/providers/categories_provider.dart';
import 'package:tally/features/groups/providers/groups_provider.dart';
import 'package:tally/features/import/logic/import_plan.dart';
import 'package:tally/features/import/providers/import_providers.dart';
import 'package:tally/features/import/ui/import_review_list.dart';
import 'package:tally/features/import/ui/import_screen.dart';
import 'package:tally/features/import/ui/merchant_rules_screen.dart';
import 'package:tally/models/category.dart';
import 'package:tally/models/group_member.dart';
import 'package:tally/models/merchant_rule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_supabase.dart';

Decimal dec(String s) => Decimal.parse(s);

const _gid = 'g1';

final _members = [
  GroupMember(
    id: 'm1',
    groupId: _gid,
    userId: 'u1',
    displayName: 'Ben',
    role: 'owner',
    joinedAt: DateTime(2026, 8, 1),
  ),
  GroupMember(
    id: 'm2',
    groupId: _gid,
    userId: null,
    displayName: 'Sam',
    role: 'member',
    joinedAt: DateTime(2026, 8, 2),
  ),
];

const _categories = [
  Category(id: 'c1', name: 'Groceries', icon: 'shopping_cart'),
  Category(id: 'c2', name: 'Food & Drink', icon: 'restaurant'),
];

final _rules = [
  const MerchantRule(
    id: 'r1',
    groupId: _gid,
    pattern: 'COSTCO WHOLESALE',
    matchType: 'contains',
    action: 'share',
    priority: 100,
    categoryId: 'c1',
  ),
];

ReviewRow _row({
  required String fingerprint,
  required String description,
  required String amount,
  bool selected = true,
  bool alreadyImported = false,
  String? categoryId,
}) =>
    ReviewRow(
      fingerprint: fingerprint,
      description: description,
      occurredOn: DateTime(2026, 8, 27),
      amount: dec(amount),
      selected: selected,
      alreadyImported: alreadyImported,
      categoryId: categoryId,
    );

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
}

Widget _host(Widget child, List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.light, home: child),
    );

void main() {
  setUpAll(initTestSupabase);

  group('ImportReviewList', () {
    testWidgets('renders a row with its date, amount and tag', (tester) async {
      _desktop(tester);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ImportReviewList(
              rows: [
                _row(
                  fingerprint: 'f1',
                  description: 'COSTCO WHOLESALE W515',
                  amount: '358.94',
                  categoryId: 'c1',
                ),
              ],
              categories: _categories,
              onToggle: (_, __) {},
              onTag: (_) {},
              onAlwaysTag: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COSTCO WHOLESALE W515'), findsOneWidget);
      expect(find.text('Aug 27'), findsOneWidget);
      expect(find.textContaining('358.94'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an untagged row offers a Tag action', (tester) async {
      _desktop(tester);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ImportReviewList(
              rows: [
                _row(fingerprint: 'f1', description: 'NEW SHOP', amount: '10'),
              ],
              categories: _categories,
              onToggle: (_, __) {},
              onTag: (_) {},
              onAlwaysTag: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tag'), findsOneWidget);
    });

    // The visible face of deduplication.
    testWidgets('an already-imported row is labelled and not selectable',
        (tester) async {
      _desktop(tester);
      addTearDown(tester.view.reset);

      var toggles = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ImportReviewList(
              rows: [
                _row(
                  fingerprint: 'f1',
                  description: 'AU MOULIN DU TEMPS',
                  amount: '66.82',
                  alreadyImported: true,
                ),
              ],
              categories: _categories,
              onToggle: (_, __) => toggles++,
              onTag: (_) {},
              onAlwaysTag: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Already imported'), findsOneWidget);

      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.onChanged, isNull, reason: 'must not be togglable');
      expect(checkbox.value, isFalse);
      expect(toggles, 0);
    });

    testWidgets('toggling a row reports back', (tester) async {
      _desktop(tester);
      addTearDown(tester.view.reset);

      bool? received;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ImportReviewList(
              rows: [
                _row(fingerprint: 'f1', description: 'SHOP', amount: '10'),
              ],
              categories: _categories,
              onToggle: (_, selected) => received = selected,
              onTag: (_) {},
              onAlwaysTag: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(received, isFalse);
    });

    testWidgets('shows an empty state when the range filters everything out',
        (tester) async {
      _desktop(tester);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ImportReviewList(
              rows: const [],
              categories: _categories,
              onToggle: (_, __) {},
              onTag: (_) {},
              onAlwaysTag: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No transactions in range'), findsOneWidget);
    });
  });

  group('ImportScreen', () {
    testWidgets('opens on the pick step and states the privacy boundary',
        (tester) async {
      _desktop(tester);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const ImportScreen(groupId: _gid), [
          membersProvider(_gid).overrideWith((ref) async => _members),
          categoriesProvider(_gid).overrideWith((ref) async => _categories),
          merchantRulesProvider(_gid).overrideWith((ref) async => _rules),
          importedFingerprintsProvider(_gid)
              .overrideWith((ref) async => <String>{}),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Import statement'), findsOneWidget);
      expect(find.text('Choose CSV file'), findsOneWidget);
      // This promise is the whole design; if the copy goes, so does the test.
      expect(
        find.textContaining('never leaves this device'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('offers the merchant rules screen from the app bar',
        (tester) async {
      _desktop(tester);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const ImportScreen(groupId: _gid), [
          membersProvider(_gid).overrideWith((ref) async => _members),
          categoriesProvider(_gid).overrideWith((ref) async => _categories),
          merchantRulesProvider(_gid).overrideWith((ref) async => _rules),
          importedFingerprintsProvider(_gid)
              .overrideWith((ref) async => <String>{}),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Merchant rules'), findsOneWidget);
    });
  });

  group('MerchantRulesScreen', () {
    testWidgets('lists the group rules', (tester) async {
      _desktop(tester);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const MerchantRulesScreen(groupId: _gid), [
          categoriesProvider(_gid).overrideWith((ref) async => _categories),
          merchantRulesProvider(_gid).overrideWith((ref) async => _rules),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('COSTCO WHOLESALE'), findsOneWidget);
      expect(find.textContaining('Groceries'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows an empty state explaining rules are group-wide',
        (tester) async {
      _desktop(tester);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const MerchantRulesScreen(groupId: _gid), [
          categoriesProvider(_gid).overrideWith((ref) async => _categories),
          merchantRulesProvider(_gid)
              .overrideWith((ref) async => <MerchantRule>[]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('No rules yet'), findsOneWidget);
      expect(find.textContaining('everyone in the group'), findsOneWidget);
    });

    testWidgets('a skip rule reads as never shared', (tester) async {
      _desktop(tester);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(const MerchantRulesScreen(groupId: _gid), [
          categoriesProvider(_gid).overrideWith((ref) async => _categories),
          merchantRulesProvider(_gid).overrideWith((ref) async => [
                const MerchantRule(
                  id: 'r2',
                  groupId: _gid,
                  pattern: 'SILVER GOBLIN',
                  matchType: 'contains',
                  action: 'skip',
                  priority: 100,
                ),
              ]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('never shared'), findsOneWidget);
    });
  });
}
