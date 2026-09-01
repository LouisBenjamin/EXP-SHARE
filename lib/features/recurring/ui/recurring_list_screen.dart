import 'package:tally/core/money.dart';
import 'package:tally/core/widgets/page_body.dart';
import 'package:tally/features/groups/providers/groups_provider.dart';
import 'package:tally/features/recurring/data/recurring_repository.dart';
import 'package:tally/features/recurring/providers/recurring_provider.dart';
import 'package:tally/models/group_member.dart';
import 'package:tally/models/recurring_expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RecurringListScreen extends ConsumerWidget {
  const RecurringListScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringProvider(groupId));
    final members = ref.watch(membersProvider(groupId)).valueOrNull ??
        const <GroupMember>[];
    final nameOf = {for (final m in members) m.id: m.displayName};

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/groups/$groupId/recurring/new');
          ref.invalidate(recurringProvider(groupId));
        },
        icon: const Icon(Icons.add),
        label: const Text('New recurring'),
      ),
      body: PageBody(
        child: recurringAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) => items.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _RecurringCard(
                    item: items[i],
                    payerName: nameOf[items[i].payerMemberId] ?? 'Member',
                    onChanged: () => ref.invalidate(recurringProvider(groupId)),
                  ),
                ),
        ),
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({
    required this.item,
    required this.payerName,
    required this.onChanged,
  });
  final RecurringExpense item;
  final String payerName;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = DateFormat('MMM d, yyyy').format(item.nextOccurrence);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description.isEmpty ? 'Recurring expense' : item.description,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatCurrency(item.amount, currency: item.currency)} · ${item.cadence}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    item.active ? 'Next: $next · paid by $payerName' : 'Paused',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: item.active,
              onChanged: (v) async {
                await RecurringRepository().setActive(id: item.id, active: v);
                onChanged();
              },
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete recurring expense?'),
                    content: Text(
                        'This stops future occurrences of "${item.description}". Past expenses are kept.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await RecurringRepository().deleteRecurring(id: item.id);
                  onChanged();
                }
              },
            ),
          ],
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
          Icon(Icons.repeat, size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No recurring expenses', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Set up rent, subscriptions, or bills\nto post automatically.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
