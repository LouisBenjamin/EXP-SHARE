import 'package:tally/features/balances/providers/balances_provider.dart';
import 'package:tally/features/expenses/providers/expenses_provider.dart';
import 'package:tally/features/groups/providers/groups_provider.dart';
import 'package:tally/models/expense.dart';
import 'package:tally/models/member_balance.dart';
import 'package:tally/models/group_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression: deleting (or adding/editing/importing) an expense used to refresh
// only the in-group providers, leaving groupSummariesProvider — the "you owe /
// you're owed" tally on the groups list — stale until a manual refresh.
// invalidateGroupMoney must hit all three.
void main() {
  testWidgets('invalidateGroupMoney refetches the groups-list tally too',
      (tester) async {
    var expenseFetches = 0;
    var balanceFetches = 0;
    var summaryFetches = 0;

    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expensesProvider('g1').overrideWith((ref) async {
            expenseFetches++;
            return <Expense>[];
          }),
          balancesProvider('g1').overrideWith((ref) async {
            balanceFetches++;
            return <MemberBalance>[];
          }),
          groupSummariesProvider.overrideWith((ref) async {
            summaryFetches++;
            return <GroupSummary>[];
          }),
        ],
        child: Consumer(
          builder: (_, r, __) {
            ref = r;
            r.watch(expensesProvider('g1'));
            r.watch(balancesProvider('g1'));
            r.watch(groupSummariesProvider);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      [expenseFetches, balanceFetches, summaryFetches],
      [1, 1, 1],
      reason: 'each provider fetched once on first watch',
    );

    invalidateGroupMoney(ref, 'g1');
    await tester.pumpAndSettle();

    expect(
      [expenseFetches, balanceFetches, summaryFetches],
      [2, 2, 2],
      reason: 'all three refetch, including the groups-list summary',
    );
  });
}
