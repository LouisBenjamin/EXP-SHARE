import 'package:decimal/decimal.dart';
import 'package:tally/core/dates.dart';

// Field-level parsing for bank statement rows. Every function returns null on
// input it can't make sense of rather than throwing, so one malformed cell
// costs one row instead of the whole import.

// The reference number is the dedup key, so it has to normalize identically no
// matter which export it came from. One export quotes it a second time, and
// those quotes survive CSV parsing: "55259565161291612668974" arrives with the
// quote characters still attached. Not all references are numeric
// (40828MBLE-241127-225678), so nothing here assumes digits.
String normalizeReference(String raw) =>
    raw.replaceAll(RegExp(r'''["'\s]'''), '').toUpperCase();

final _currencyNoise = RegExp(r'[$,\s]');
final _unsignedDecimal = RegExp(r'^\d*\.?\d+$');

// '$66.82' -> 66.82   '-$1000.00' -> -1000.00   '$1,234.56' -> 1234.56
// '($5.00)' -> -5.00  ''/'n/a' -> null
//
// The minus sign precedes the currency symbol in these exports, and some banks
// use accounting parentheses instead, so the sign is pulled off before the
// symbol is stripped.
Decimal? parseStatementAmount(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;

  var negative = false;
  if (text.startsWith('(') && text.endsWith(')')) {
    negative = true;
    text = text.substring(1, text.length - 1);
  }
  if (text.startsWith('-')) {
    negative = true;
    text = text.substring(1);
  } else if (text.startsWith('+')) {
    text = text.substring(1);
  }

  text = text.replaceAll(_currencyNoise, '');

  // The sign has already been taken off, so anything left that isn't a bare
  // decimal is malformed ('--5', '1.2.3'). Without this check the leading '-'
  // of '--5' survives into Decimal and the sign gets applied twice.
  if (!_unsignedDecimal.hasMatch(text)) return null;

  final value = Decimal.tryParse(text);
  if (value == null) return null;
  return negative ? -value : value;
}

final _slashOrDash = RegExp(r'^(\d{1,4})[/-](\d{1,2})[/-](\d{1,4})$');
const _months = <String, int>{
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};
final _namedMonth = RegExp(
  r'^([a-z]{3})[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})$',
  caseSensitive: false,
);

DateTime? _build(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  // Reject 2026-02-30, which DateTime would roll over into March.
  if (date.month != month || date.day != day) return null;
  return date;
}

// Every sample statement uses ISO, so the other branches are purely defensive.
// Ambiguous slash dates use the North American default (month first) unless the
// first component is over 12, which forces day-first. Deliberately no
// column-wide format inference: there is no real data to justify it.
DateTime? parseStatementDate(String raw) {
  final text = raw.replaceAll('"', '').trim();
  if (text.isEmpty) return null;

  final iso = parseIsoDate(text);
  if (iso != null) return iso;

  final slash = _slashOrDash.firstMatch(text);
  if (slash != null) {
    final a = int.parse(slash.group(1)!);
    final b = int.parse(slash.group(2)!);
    final c = int.parse(slash.group(3)!);

    if (slash.group(1)!.length == 4) return _build(a, b, c); // yyyy/MM/dd
    if (a > 12) return _build(c, b, a); // dd/MM/yyyy
    return _build(c, a, b); // MM/dd/yyyy
  }

  final named = _namedMonth.firstMatch(text);
  if (named != null) {
    final month = _months[named.group(1)!.toLowerCase()];
    if (month == null) return null;
    return _build(int.parse(named.group(3)!), month, int.parse(named.group(2)!));
  }

  return null;
}

// Non-destructive: only case and whitespace. Used for rule MATCHING, so a
// 'GOOGLE' rule still matches 'GOOGLE*Spotify Music'. Stripping the processor
// prefix here would make that rule impossible to write.
String normalizeMerchant(String raw) =>
    raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

// Payment-processor prefixes that carry no merchant information.
final _processorPrefix = RegExp(r'^[A-Z0-9+]{2,6}\s*\*\s*');
// Trailing store/terminal codes: 'COSTCO WHOLESALE W515', 'SUBWAY #1234'.
final _storeSuffix = RegExp(r'\s+(?:[#]\d+|[A-Z]\d{2,5})$');

// Destructive, and used ONLY to prefill the "always tag this merchant" dialog.
// Both 'COSTCO WHOLESALE W515' and 'COSTCO WHOLESALE W521' collapse to
// 'COSTCO WHOLESALE', so the rule the user saves covers every store rather
// than the single one they happened to be looking at.
String suggestRulePattern(String merchantName) {
  var text = normalizeMerchant(merchantName);
  text = text.replaceFirst(_processorPrefix, '');
  // Applied repeatedly: 'COSTCO GAS W521 #12' has two trailing codes.
  var previous = '';
  while (previous != text) {
    previous = text;
    text = text.replaceFirst(_storeSuffix, '').trim();
  }
  return text.isEmpty ? normalizeMerchant(merchantName) : text;
}
