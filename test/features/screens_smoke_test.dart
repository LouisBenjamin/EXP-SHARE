import 'package:decimal/decimal.dart';
import 'package:exp_share/core/theme.dart';
import 'package:exp_share/features/balances/providers/balances_provider.dart';
import 'package:exp_share/features/expenses/providers/categories_provider.dart';
import 'package:exp_share/features/expenses/providers/expenses_provider.dart';
import 'package:exp_share/features/expenses/ui/add_expense_screen.dart';
import 'package:exp_share/features/groups/providers/groups_provider.dart';
import 'package:exp_share/features/groups/ui/group_detail_screen.dart';
import 'package:exp_share/features/insights/data/insights_repository.dart';
import 'package:exp_share/features/insights/providers/insights_provider.dart';
import 'package:exp_share/features/insights/ui/insights_screen.dart';
import 'package:exp_share/features/realtime/group_realtime_provider.dart';
import 'package:exp_share/features/recurring/providers/recurring_provider.dart';
import 'package:exp_share/features/recurring/ui/recurring_list_screen.dart';
import 'package:exp_share/models/category.dart';
import 'package:exp_share/models/expense.dart';
import 'package:exp_share/models/group.dart';
import 'package:exp_share/models/group_member.dart';
import 'package:exp_share/models/member_balance.dart';
import 'package:exp_share/models/recurring_expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_supabase.dart';

Decimal dec(String s) => Decimal.parse(s);

const _gid = 'g1';

final _group = Group(
  id: _gid,
  name: 'Apartment',
  joinCode: 'AB452A',
  createdBy: 'u1',
  createdAt: DateTime(2026, 8, 1),
);

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

final _expenses = [
  Expense(
    id: 'e1',
    groupId: _gid,
    payerMemberId: 'm1',
    amount: dec('90.00'),
    currency: 'CAD',
    description: 'Groceries',
    occurredOn: DateTime(2026, 8, 12),
    splitType: 'equal',
    createdBy: 'u1',
    createdAt: DateTime(2026, 8, 12),
  ),
];

final _balances = [
  MemberBalance(memberId: 'm1', net: Decimal.zero),
  MemberBalance(memberId: 'm2', net: Decimal.zero),
];

Widget _host(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.light, home: child),
  );
}

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
}

void main() {
  setUpAll(initTestSupabase);

  testWidgets('InsightsScreen renders a category breakdown', (tester) async {
    _desktop(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(
      const InsightsScreen(groupId: _gid),
      [
        insightsProvider(_gid).overrideWith((ref) async => [
              CategorySpend(name: 'Rent', icon: 'home', total: dec('1000')),
              CategorySpend(
                  name: 'Groceries', icon: 'shopping_cart', total: dec('250')),
            ]),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('InsightsScreen shows an empty message with no spend',
      (tester) async {
    _desktop(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(
      const InsightsScreen(groupId: _gid),
      [insightsProvider(_gid).overrideWith((ref) async => <CategorySpend>[])],
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No spending'), findsOneWidget);
  });

  testWidgets('RecurringListScreen renders templates with cadence',
      (tester) async {
    _desktop(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(
      const RecurringListScreen(groupId: _gid),
      [
        membersProvider(_gid).overrideWith((ref) async => _members),
        recurringProvider(_gid).overrideWith((ref) async => [
              RecurringExpense(
                id: 'r1',
                groupId: _gid,
                payerMemberId: 'm1',
                amount: dec('1000'),
                currency: 'CAD',
                description: 'Rent',
                splitType: 'equal',
                frequency: 'monthly',
                intervalCount: 1,
                nextOccurrence: DateTime(2026, 10, 1),
                active: true,
              ),
            ]),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);
    expect(find.textContaining('Every month'), findsOneWidget);
  });

  testWidgets('RecurringListScreen shows its empty state', (tester) async {
    _desktop(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(
      const RecurringListScreen(groupId: _gid),
      [
        membersProvider(_gid).overrideWith((ref) async => _members),
        recurringProvider(_gid)
            .overrideWith((ref) async => <RecurringExpense>[]),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('No recurring expenses'), findsOneWidget);
  });

  testWidgets('AddExpenseScreen builds the new-expense form', (tester) async {
    _desktop(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(
      const AddExpenseScreen(groupId: _gid),
      [
        membersProvider(_gid).overrideWith((ref) async => _members),
        categoriesProvider(_gid).overrideWith((ref) async => [
              const Category(id: 'c1', name: 'Food', icon: 'restaurant'),
            ]),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    // Split type selector + a participant row per member.
    expect(find.text('Equally'), findsOneWidget);
    expect(find.text('Ben'), findsWidgets);
    expect(find.text('Sam'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GroupDetailScreen renders its three tabs', (tester) async {
    _desktop(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(
      const GroupDetailScreen(groupId: _gid),
      [
        groupProvider(_gid).overrideWith((ref) async => _group),
        membersProvider(_gid).overrideWith((ref) async => _members),
        expensesProvider(_gid).overrideWith((ref) async => _expenses),
        balancesProvider(_gid).overrideWith((ref) async => _balances),
        groupRealtimeProvider(_gid).overrideWithValue(null),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Apartment'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Balances'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Balances'));
    await tester.pumpAndSettle();
    expect(find.text('All settled up'), findsOneWidget);

    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Members ('), findsOneWidget);
    expect(find.text('AB452A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
