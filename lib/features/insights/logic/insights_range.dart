/// A selectable time window for the Insights breakdown.
///
/// Boundaries are local-midnight dates computed with calendar arithmetic
/// (`DateTime(y, m, d ± n)`), never `Duration` — see the DST note in
/// `core/dates.dart`. `from` is inclusive, `toExclusive` is the start of the
/// day after "today", so a `>= from` / `< toExclusive` filter covers today.
typedef DateWindow = ({DateTime from, DateTime toExclusive});

enum InsightsRange {
  lastWeek('Last week'),
  monthToDate('Month to date'),
  yearToDate('Year to date');

  const InsightsRange(this.label);

  final String label;

  DateWindow window(DateTime now) {
    final toExclusive = DateTime(now.year, now.month, now.day + 1);
    final from = switch (this) {
      InsightsRange.lastWeek => DateTime(now.year, now.month, now.day - 6),
      InsightsRange.monthToDate => DateTime(now.year, now.month, 1),
      InsightsRange.yearToDate => DateTime(now.year, 1, 1),
    };
    return (from: from, toExclusive: toExclusive);
  }
}
