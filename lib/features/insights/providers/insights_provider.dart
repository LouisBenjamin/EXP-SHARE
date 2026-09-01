import 'package:tally/features/insights/data/insights_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Current-month spend per category for a group.
final insightsProvider =
    FutureProvider.family<List<CategorySpend>, String>((ref, groupId) {
  return InsightsRepository()
      .monthlyByCategory(groupId: groupId, month: DateTime.now());
});
