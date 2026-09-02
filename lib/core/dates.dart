import 'package:intl/intl.dart';

// Date-only helpers. `expenses.occurred_on` and the dates on an imported bank
// statement are date-only values, not instants: never call .toLocal() on one
// or compare it against DateTime.now(), or a timezone offset silently shifts
// the day. Keep them as local midnight and compare them as ISO strings.

// yyyy-MM-dd, zero-padded — the wire format for a Postgres `date` column.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

// Strict yyyy-MM-dd. Returns null rather than throwing so a caller parsing a
// statement can report one bad row instead of aborting the whole file.
DateTime? parseIsoDate(String value) {
  final match = _isoPattern.firstMatch(value.trim());
  if (match == null) return null;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);

  // DateTime silently rolls out-of-range components over (month 13 becomes
  // January of the next year), so round-trip to reject 2026-13-45.
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

// Display formats, matching what the expense and recurring screens already use.
String formatDay(DateTime d) => DateFormat('MMM d').format(d);

String formatDayYear(DateTime d) => DateFormat('MMM d, yyyy').format(d);
