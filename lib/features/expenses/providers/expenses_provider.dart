import 'package:exp_share/features/expenses/data/expenses_repository.dart';
import 'package:exp_share/models/expense.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Keyed by groupId. Invalidate with ref.invalidate(expensesProvider(groupId))
// after creating or deleting an expense.
final expensesProvider = FutureProvider.family<List<Expense>, String>(
  (ref, groupId) => ExpensesRepository().fetchExpenses(groupId: groupId),
);
