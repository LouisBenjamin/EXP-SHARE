import 'package:decimal/decimal.dart';
import 'package:tally/core/dates.dart';
import 'package:tally/core/icons.dart';
import 'package:tally/core/money.dart';
import 'package:tally/core/widgets/page_body.dart';
import 'package:tally/features/insights/data/insights_repository.dart';
import 'package:tally/features/insights/logic/insights_range.dart';
import 'package:tally/features/insights/providers/insights_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  InsightsRange _range = InsightsRange.monthToDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spendAsync =
        ref.watch(insightsProvider((groupId: widget.groupId, range: _range)));

    final now = DateTime.now();
    final window = _range.window(now);
    final lastDay = DateTime(now.year, now.month, now.day);
    final spanLabel = '${formatDay(window.from)} – ${formatDayYear(lastDay)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Spending', style: theme.textTheme.titleMedium),
                ),
                DropdownButton<InsightsRange>(
                  value: _range,
                  onChanged: (r) {
                    if (r != null) setState(() => _range = r);
                  },
                  items: [
                    for (final r in InsightsRange.values)
                      DropdownMenuItem(value: r, child: Text(r.label)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: PageBody(
              child: spendAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (spend) {
                  if (spend.isEmpty) {
                    return Center(
                      child: Text(
                        'No spending for ${_range.label.toLowerCase()} yet',
                        style: theme.textTheme.titleMedium,
                      ),
                    );
                  }
                  final total =
                      spend.fold(Decimal.zero, (s, c) => s + c.total);
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_range.label, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        spanLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
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
          ),
        ],
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
