import 'package:decimal/decimal.dart';
import 'package:tally/core/icons.dart';
import 'package:tally/core/money.dart';
import 'package:tally/features/balances/data/balances_repository.dart';
import 'package:tally/features/balances/logic/settle.dart';
import 'package:tally/features/balances/providers/balances_provider.dart';
import 'package:tally/features/groups/providers/groups_provider.dart';
import 'package:tally/models/group_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
class BalancesTab extends ConsumerWidget {
  const BalancesTab({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(balancesProvider(groupId));
    final membersAsync = ref.watch(membersProvider(groupId));

    return balancesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (balances) {
        final members = membersAsync.valueOrNull ?? const <GroupMember>[];
        final nameOf = {for (final m in members) m.id: m.displayName};

        final owing = balances.where((b) => b.net != Decimal.zero).toList()
          ..sort((a, b) => b.net.compareTo(a.net));
        final transfers = simplifyDebts(balances);

        if (owing.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.success, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('All settled up', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text('Balances', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...owing.map((b) => _BalanceRow(
                  name: nameOf[b.memberId] ?? 'Member',
                  net: b.net,
                )),
            if (transfers.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Suggested settlements',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...transfers.map((t) => _SettlementRow(
                    groupId: groupId,
                    transfer: t,
                    fromName: nameOf[t.fromMemberId] ?? 'Member',
                    toName: nameOf[t.toMemberId] ?? 'Member',
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.name, required this.net});
  final String name;
  final Decimal net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owed = net > Decimal.zero;
    final color = owed ? Colors.green.shade700 : theme.colorScheme.error;
    final label = owed ? 'gets back' : 'owes';
    final abs = owed ? net : Decimal.zero - net;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?'),
      ),
      title: Text(name),
      subtitle: Text(label),
      trailing: Text(
        formatCurrency(abs),
        style: theme.textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SettlementRow extends ConsumerStatefulWidget {
  const _SettlementRow({
    required this.groupId,
    required this.transfer,
    required this.fromName,
    required this.toName,
  });
  final String groupId;
  final DebtTransfer transfer;
  final String fromName;
  final String toName;

  @override
  ConsumerState<_SettlementRow> createState() => _SettlementRowState();
}

class _SettlementRowState extends ConsumerState<_SettlementRow> {
  bool _saving = false;

  Future<void> _settle() async {
    final t = widget.transfer;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Record settlement'),
        content: Text(
          '${widget.fromName} paid ${widget.toName} '
          '${formatCurrency(t.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await BalancesRepository().settle(
        groupId: widget.groupId,
        fromMemberId: t.fromMemberId,
        toMemberId: t.toMemberId,
        amount: t.amount.toString(),
      );
      invalidateGroupMoney(ref, widget.groupId);
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
    final theme = Theme.of(context);
    final t = widget.transfer;
    return Card(
      child: ListTile(
        leading: const Icon(AppIcons.arrowForward),
        title: Text('${widget.fromName} → ${widget.toName}'),
        subtitle: Text(formatCurrency(t.amount)),
        trailing: _saving
            ? const SizedBox(
                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(
                onPressed: _settle,
                child: const Text('Settle up'),
              ),
        titleTextStyle: theme.textTheme.titleSmall,
      ),
    );
  }
}
