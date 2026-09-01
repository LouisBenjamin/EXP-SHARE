import 'package:exp_share/features/expenses/data/expenses_repository.dart';
import 'package:exp_share/models/expense_split.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Splits for one expense, keyed by expenseId — used to pre-fill the edit form.
final expenseSplitsProvider =
    FutureProvider.family<List<ExpenseSplit>, String>(
  (ref, expenseId) => ExpensesRepository().fetchSplits(expenseId: expenseId),
);
