import 'package:tally/core/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isoDate', () {
    test('zero-pads single-digit months and days', () {
      expect(isoDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('leaves two-digit components alone', () {
      expect(isoDate(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('sorts lexicographically in chronological order', () {
      final dates = [
        DateTime(2026, 10, 2),
        DateTime(2026, 2, 10),
        DateTime(2025, 12, 31),
      ].map(isoDate).toList()
        ..sort();
      expect(dates, ['2025-12-31', '2026-02-10', '2026-10-02']);
    });
  });

  group('parseIsoDate', () {
    test('round-trips through isoDate', () {
      for (final date in [
        DateTime(2026, 1, 5),
        DateTime(2026, 8, 30),
        DateTime(2024, 2, 29), // leap day
      ]) {
        expect(parseIsoDate(isoDate(date)), date, reason: isoDate(date));
      }
    });

    test('tolerates surrounding whitespace', () {
      expect(parseIsoDate('  2026-08-30 '), DateTime(2026, 8, 30));
    });

    test('rejects out-of-range components instead of rolling them over', () {
      // DateTime(2026, 13, 45) would silently become 2027-02-14.
      expect(parseIsoDate('2026-13-45'), isNull);
      expect(parseIsoDate('2026-02-30'), isNull);
      expect(parseIsoDate('2025-02-29'), isNull); // 2025 is not a leap year
    });

    test('rejects anything that is not a bare yyyy-MM-dd', () {
      for (final bad in [
        '',
        'not a date',
        '2026-8-30', // unpadded
        '30-08-2026',
        '2026/08/30',
        '2026-08-30T12:00:00Z', // an instant, not a date
      ]) {
        expect(parseIsoDate(bad), isNull, reason: bad);
      }
    });
  });

  group('display formats', () {
    test('formatDay omits the year', () {
      expect(formatDay(DateTime(2026, 8, 30)), 'Aug 30');
    });

    test('formatDayYear includes it', () {
      expect(formatDayYear(DateTime(2026, 8, 30)), 'Aug 30, 2026');
    });
  });
}
