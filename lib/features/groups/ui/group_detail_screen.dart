import 'package:exp_share/features/expenses/providers/expenses_provider.dart';
import 'package:exp_share/features/groups/providers/groups_provider.dart';
import 'package:exp_share/models/expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final expensesAsync = ref.watch(expensesProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: groupAsync.when(
          loading: () => const Text('Loading…'),
          error: (_, __) => const Text('Group'),
          data: (g) => Text(g.name),
        ),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/groups/$groupId/expenses/new');
          ref.invalidate(expensesProvider(groupId));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) => expenses.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: expenses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ExpenseCard(expense: expenses[i]),
              ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d').format(expense.occurredOn);
    final amountStr = '\$${expense.amount.toStringAsFixed(2)}';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(
            Icons.receipt_outlined,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          expense.description.isEmpty ? 'Expense' : expense.description,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          dateStr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Text(
          amountStr,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No expenses yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tap + to log the first one.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
