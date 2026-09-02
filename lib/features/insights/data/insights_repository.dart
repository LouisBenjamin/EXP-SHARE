import 'package:decimal/decimal.dart';
import 'package:tally/core/dates.dart';
import 'package:tally/core/supabase_client.dart';

class CategorySpend {
  const CategorySpend({
    required this.name,
    required this.icon,
    required this.total,
  });
  final String name;
  final String icon;
  final Decimal total;
}

class InsightsRepository {
  // Total spend per category between [from] (inclusive) and [toExclusive]
  // (exclusive) in a group, deleted expenses excluded.
  Future<List<CategorySpend>> byCategory({
    required String groupId,
    required DateTime from,
    required DateTime toExclusive,
  }) async {
    final data = await supabase
        .from('expenses')
        .select('amount, categories(name, icon)')
        .eq('group_id', groupId)
        .isFilter('deleted_at', null)
        .gte('occurred_on', isoDate(from))
        .lt('occurred_on', isoDate(toExclusive));

    final totals = <String, ({String icon, Decimal total})>{};
    for (final row in data as List) {
      final map = row as Map<String, dynamic>;
      final cat = map['categories'] as Map<String, dynamic>?;
      final name = cat?['name'] as String? ?? 'Uncategorized';
      final icon = cat?['icon'] as String? ?? 'more_horiz';
      final amount = Decimal.parse(map['amount'].toString());
      final existing = totals[name];
      totals[name] = (
        icon: icon,
        total: (existing?.total ?? Decimal.zero) + amount,
      );
    }

    final list = totals.entries
        .map((e) =>
            CategorySpend(name: e.key, icon: e.value.icon, total: e.value.total))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }
}
