import 'package:tally/features/insights/data/insights_repository.dart';
import 'package:tally/features/insights/logic/insights_range.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef InsightsArgs = ({String groupId, InsightsRange range});

// Spend per category for a group over the selected [InsightsRange]. Keyed by
// (groupId, range) so each range stays cached independently.
final insightsProvider =
    FutureProvider.family<List<CategorySpend>, InsightsArgs>((ref, args) {
  final w = args.range.window(DateTime.now());
  return InsightsRepository().byCategory(
    groupId: args.groupId,
    from: w.from,
    toExclusive: w.toExclusive,
  );
});
