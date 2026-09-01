import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:decimal/decimal.dart';
import 'package:tally/features/import/logic/csv_dialect.dart';
import 'package:tally/features/import/logic/field_parsers.dart';

// One usable line from a statement. Everything here stays on the device: only
// the amount, date, and a chosen description ever reach the server, and only
// for rows the user explicitly promotes to a group expense.
class ParsedTransaction {
  const ParsedTransaction({
    required this.reference,
    required this.occurredOn,
    required this.merchantName,
    required this.merchantNormalized,
    required this.merchantCategory,
    required this.amount,
    required this.line,
    this.postedOn,
    this.cardLast4,
  });

  final String reference; // already normalized — see normalizeReference
  final DateTime occurredOn; // date-only; the transaction date, not the posted date
  final DateTime? postedOn;
  final String merchantName;
  final String merchantNormalized; // uppercased/collapsed, for rule matching
  final String merchantCategory;
  final Decimal amount; // always positive; credits never reach here
  final int line; // 1-based source line, so an issue can name the row
  final String? cardLast4;
}

// A row that couldn't be used. Never fatal on its own — the rest of the file
// still imports, and the user sees a count.
class RowIssue {
  const RowIssue({required this.line, required this.message});

  final int line;
  final String message;
}

// Follows the SplitOutcome convention: a result object carrying validity and a
// human-readable status, never a thrown exception.
class StatementParseResult {
  const StatementParseResult({
    required this.valid,
    required this.status,
    required this.dialect,
    required this.transactions,
    required this.issues,
    required this.skippedCredits,
  });

  final bool valid;
  final String status;
  final String dialect;
  final List<ParsedTransaction> transactions;
  final List<RowIssue> issues;
  final int skippedCredits; // payments and refunds, dropped at parse time

  static StatementParseResult _fail(String status) => StatementParseResult(
        valid: false,
        status: status,
        dialect: 'unknown',
        transactions: const [],
        issues: const [],
        skippedCredits: 0,
      );
}

// The seam a PDF parser plugs into later: add it to kStatementParsers and
// nothing else in the feature changes.
//
// Works on bytes rather than a file path on purpose — the app targets web,
// where a picked file has bytes and no path, and the codebase has no dart:io
// anywhere.
abstract interface class StatementParser {
  String get label;
  bool canParse(String fileName, Uint8List bytes);
  StatementParseResult parse(Uint8List bytes);
}

class CsvStatementParser implements StatementParser {
  const CsvStatementParser();

  @override
  String get label => 'CSV';

  @override
  bool canParse(String fileName, Uint8List bytes) =>
      fileName.toLowerCase().endsWith('.csv');

  @override
  StatementParseResult parse(Uint8List bytes) =>
      parseStatementCsv(_decode(bytes));
}

const kStatementParsers = <StatementParser>[CsvStatementParser()];

StatementParseResult parseStatement(String fileName, Uint8List bytes) {
  for (final parser in kStatementParsers) {
    if (parser.canParse(fileName, bytes)) return parser.parse(bytes);
  }
  return StatementParseResult._fail(
    "Tally can't read this file type yet. Export your statement as CSV.",
  );
}

// allowMalformed is deliberate: a single bad byte in a merchant name should
// mangle that name, not throw away the whole statement.
String _decode(Uint8List bytes) =>
    utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', '');

String _cell(List<dynamic> row, int? index) {
  if (index == null || index < 0 || index >= row.length) return '';
  return (row[index] ?? '').toString().trim();
}

// The pure entry point, so tests never need bytes or a file.
StatementParseResult parseStatementCsv(String csvText) {
  final text = csvText.replaceFirst('﻿', '').replaceAll('\r\n', '\n');
  if (text.trim().isEmpty) {
    return StatementParseResult._fail('That file is empty.');
  }

  // shouldParseNumbers must stay false: a 23-digit reference number would
  // otherwise be read as a double and lose its last digits, silently breaking
  // deduplication.
  final rows = const CsvToListConverter(
    shouldParseNumbers: false,
    eol: '\n',
  ).convert(text);

  if (rows.isEmpty) {
    return StatementParseResult._fail('That file is empty.');
  }

  final header = mapHeader([for (final c in rows.first) (c ?? '').toString()]);
  if (!header.valid) return StatementParseResult._fail(header.status);

  final transactions = <ParsedTransaction>[];
  final issues = <RowIssue>[];
  final seen = <String>{};
  var skippedCredits = 0;
  var skippedStatus = 0;

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final line = i + 1; // 1-based, counting the header

    // Trailing blank line.
    if (row.every((c) => (c ?? '').toString().trim().isEmpty)) continue;

    final status = _cell(row, header.indexOf(StatementField.status));
    if (status.isNotEmpty && status.toUpperCase() != 'APPROVED') {
      skippedStatus++;
      continue;
    }

    final reference = _cell(row, header.indexOf(StatementField.referenceNumber));
    if (normalizeReference(reference).isEmpty) {
      issues.add(RowIssue(line: line, message: 'no reference number'));
      continue;
    }

    final date = parseStatementDate(
      _cell(row, header.indexOf(StatementField.transactionDate)),
    );
    if (date == null) {
      issues.add(RowIssue(line: line, message: 'unreadable date'));
      continue;
    }

    final amount = parseStatementAmount(
      _cell(row, header.indexOf(StatementField.amount)),
    );
    if (amount == null) {
      issues.add(RowIssue(line: line, message: 'unreadable amount'));
      continue;
    }

    // Payments and refunds are dropped here rather than carried through the
    // pipeline: expenses.amount has check (amount > 0), so a credit could
    // never become a shared expense anyway.
    if (amount <= Decimal.zero) {
      skippedCredits++;
      continue;
    }

    // Defensive — the real exports have unique references within a file.
    final key = normalizeReference(reference);
    if (!seen.add(key)) {
      issues.add(RowIssue(line: line, message: 'duplicate reference in file'));
      continue;
    }

    final merchant = _cell(row, header.indexOf(StatementField.merchantName));
    final card = _cell(row, header.indexOf(StatementField.cardNumber));

    transactions.add(
      ParsedTransaction(
        // Normalized, not raw: one export leaves quotes attached, and a
        // reference that means two different strings depending on the export
        // it came from is exactly what breaks deduplication.
        reference: key,
        occurredOn: date,
        postedOn: parseStatementDate(
          _cell(row, header.indexOf(StatementField.postedDate)),
        ),
        merchantName: merchant,
        merchantNormalized: normalizeMerchant(merchant),
        merchantCategory:
            _cell(row, header.indexOf(StatementField.merchantCategory)),
        amount: amount,
        line: line,
        cardLast4: card.length >= 4
            ? card.substring(card.length - 4)
            : (card.isEmpty ? null : card),
      ),
    );
  }

  return StatementParseResult(
    valid: true,
    status: _summarize(
      transactions.length,
      skippedCredits,
      skippedStatus,
      issues.length,
    ),
    dialect: header.dialect,
    transactions: transactions,
    issues: issues,
    skippedCredits: skippedCredits,
  );
}

String _summarize(int kept, int credits, int pending, int issues) {
  final parts = <String>['$kept transaction${kept == 1 ? '' : 's'}'];
  if (credits > 0) parts.add('$credits payment/refund hidden');
  if (pending > 0) parts.add('$pending not yet approved');
  if (issues > 0) parts.add('$issues row${issues == 1 ? '' : 's'} skipped');
  return parts.join(' · ');
}
