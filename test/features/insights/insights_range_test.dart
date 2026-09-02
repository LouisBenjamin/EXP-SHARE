import 'package:flutter_test/flutter_test.dart';
import 'package:tally/features/insights/logic/insights_range.dart';

void main() {
  group('InsightsRange.window', () {
    test('mid-month reference date', () {
      final now = DateTime(2026, 9, 15, 13, 30);

      expect(InsightsRange.lastWeek.window(now),
          (from: DateTime(2026, 9, 9), toExclusive: DateTime(2026, 9, 16)));
      expect(InsightsRange.monthToDate.window(now),
          (from: DateTime(2026, 9, 1), toExclusive: DateTime(2026, 9, 16)));
      expect(InsightsRange.yearToDate.window(now),
          (from: DateTime(2026, 1, 1), toExclusive: DateTime(2026, 9, 16)));
    });

    test('last week rolls back across a month boundary', () {
      final now = DateTime(2026, 3, 3);
      expect(InsightsRange.lastWeek.window(now).from, DateTime(2026, 2, 25));
    });

    test('last week rolls back across a year boundary', () {
      final now = DateTime(2026, 1, 2);
      expect(InsightsRange.lastWeek.window(now).from, DateTime(2025, 12, 27));
      expect(InsightsRange.yearToDate.window(now).from, DateTime(2026, 1, 1));
      expect(InsightsRange.monthToDate.window(now).from, DateTime(2026, 1, 1));
    });
  });
}
