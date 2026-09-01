import 'package:exp_share/core/money.dart';
import 'package:exp_share/core/supabase_client.dart';
import 'package:exp_share/features/balances/providers/balances_provider.dart';
import 'package:exp_share/features/balances/ui/balances_tab.dart';
import 'package:exp_share/features/expenses/providers/expenses_provider.dart';
import 'package:exp_share/features/groups/data/groups_repository.dart';
import 'package:exp_share/features/groups/providers/groups_provider.dart';
import 'package:exp_share/models/expense.dart';
import 'package:exp_share/models/group_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab =
      TabController(length: 3, vsync: this)..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _addExpense() async {
    await context.push('/groups/${widget.groupId}/expenses/new');
    ref.invalidate(expensesProvider(widget.groupId));
    ref.invalidate(balancesProvider(widget.groupId));
  }

  Future<void> _addGuest() async {
    await showDialog(
      context: context,
      builder: (_) => _AddGuestDialog(groupId: widget.groupId),
    );
    ref.invalidate(membersProvider(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: groupAsync.when(
          loading: () => const Text('Loading…'),
          error: (_, __) => const Text('Group'),
          data: (g) => Text(g.name),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Insights',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/groups/${widget.groupId}/insights'),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      floatingActionButton: switch (_tab.index) {
        0 => FloatingActionButton.extended(
            onPressed: _addExpense,
            icon: const Icon(Icons.add),
            label: const Text('Add expense'),
          ),
        2 => FloatingActionButton.extended(
            onPressed: _addGuest,
            icon: const Icon(Icons.person_add),
            label: const Text('Add guest'),
          ),
        _ => null,
      },
      body: TabBarView(
        controller: _tab,
        children: [
          _ExpensesTab(groupId: widget.groupId),
          BalancesTab(groupId: widget.groupId),
          _MembersTab(groupId: widget.groupId),
        ],
      ),
    );
  }
}

// ============================================================ Expenses tab

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider(groupId));
    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (expenses) => expenses.isEmpty
          ? const _EmptyState(
              icon: Icons.receipt_long,
              title: 'No expenses yet',
              subtitle: 'Tap + to log the first one.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: expenses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _ExpenseCard(expense: expenses[i]),
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
    final amountStr = formatCurrency(expense.amount, currency: expense.currency);

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

// ============================================================ Members tab

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final membersAsync = ref.watch(membersProvider(groupId));
    final myUserId = supabase.auth.currentUser?.id;

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (members) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          groupAsync.maybeWhen(
            data: (g) => _JoinCodeCard(code: g.joinCode),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          Text('Members (${members.length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...members.map((m) => _MemberTile(
                member: m,
                isYou: m.userId != null && m.userId == myUserId,
              )),
        ],
      ),
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.key, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite code',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      )),
                  Text(
                    code,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              icon: Icon(Icons.copy, color: theme.colorScheme.onPrimaryContainer),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.isYou});
  final GroupMember member;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: member.isGuest
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        child: Text(
          member.displayName.isNotEmpty
              ? member.displayName.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(
            color: member.isGuest
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(member.displayName)),
          if (isYou) ...[
            const SizedBox(width: 8),
            _Chip(label: 'You', color: theme.colorScheme.primary),
          ],
          if (member.isGuest) ...[
            const SizedBox(width: 8),
            _Chip(label: 'Guest', color: theme.colorScheme.outline),
          ],
        ],
      ),
      subtitle: member.role == 'owner' ? const Text('Owner') : null,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _AddGuestDialog extends ConsumerStatefulWidget {
  const _AddGuestDialog({required this.groupId});
  final String groupId;

  @override
  ConsumerState<_AddGuestDialog> createState() => _AddGuestDialogState();
}

class _AddGuestDialogState extends ConsumerState<_AddGuestDialog> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await GroupsRepository().addGuest(groupId: widget.groupId, name: name);
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add guest'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _save(),
        decoration: const InputDecoration(
          labelText: 'Guest name',
          hintText: 'e.g. Sam (no account)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

// ============================================================ Shared

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
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
