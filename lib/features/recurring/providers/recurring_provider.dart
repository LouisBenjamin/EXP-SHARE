import 'package:exp_share/features/recurring/data/recurring_repository.dart';
import 'package:exp_share/models/recurring_expense.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Recurring templates for a group. Invalidate after create/toggle/delete.
final recurringProvider =
    FutureProvider.family<List<RecurringExpense>, String>(
  (ref, groupId) => RecurringRepository().fetchRecurring(groupId: groupId),
);
