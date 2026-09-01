import 'package:decimal/decimal.dart';
import 'package:tally/core/money.dart';
import 'package:tally/core/widgets/page_body.dart';
import 'package:tally/features/expenses/providers/categories_provider.dart';
import 'package:tally/features/insights/data/insights_repository.dart';
import 'package:tally/features/insights/providers/insights_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spendAsync = ref.watch(insightsProvider(groupId));
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: PageBody(
        child: spendAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (spend) {
            if (spend.isEmpty) {
              return Center(
                child: Text('No spending in $monthLabel yet',
                    style: theme.textTheme.titleMedium),
              );
            }
            final total = spend.fold(Decimal.zero, (s, c) => s + c.total);
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(monthLabel, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(total),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                ...spend.map((c) => _CategoryBar(spend: c, total: total)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.spend, required this.total});
  final CategorySpend spend;
  final Decimal total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total > Decimal.zero
        ? (spend.total / total).toDouble().clamp(0.0, 1.0)
        : 0.0;
    final pct = (fraction * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconForCategory(spend.icon), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(spend.name, style: theme.textTheme.bodyLarge)),
              Text('${formatCurrency(spend.total)}  ·  $pct%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
