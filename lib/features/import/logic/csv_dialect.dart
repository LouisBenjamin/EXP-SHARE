// Header detection for bank statement CSVs.
//
// The same bank exports the same data under different column names depending
// on which screen you download from, so the parser never hard-codes a column
// order. Every known spelling folds into one alias table; supporting another
// export is one more entry, not another parser.

// The columns the importer knows how to use. Anything else in the file is
// ignored, so an export that gains columns still parses.
enum StatementField {
  transactionDate,
  postedDate,
  referenceNumber,
  activityType,
  status,
  cardNumber,
  merchantCategory,
  merchantName,
  amount,
}

// Header spelling -> field. Keys are already normalized (see _normalizeHeader).
const _aliases = <String, StatementField>{
  'date': StatementField.transactionDate,
  'transaction date': StatementField.transactionDate,
  'posted date': StatementField.postedDate,
  'reference number': StatementField.referenceNumber,
  'activity type': StatementField.activityType,
  'status': StatementField.status,
  'activity status': StatementField.status,
  'card number': StatementField.cardNumber,
  'merchant category': StatementField.merchantCategory,
  'merchant category description': StatementField.merchantCategory,
  'merchant name': StatementField.merchantName,
  'amount': StatementField.amount,
};

// Without these a row cannot become an expense, so a file missing any of them
// is rejected outright rather than parsed into useless rows.
const _required = <StatementField>[
  StatementField.transactionDate,
  StatementField.referenceNumber,
  StatementField.merchantName,
  StatementField.amount,
];

const _fieldLabels = <StatementField, String>{
  StatementField.transactionDate: 'Date',
  StatementField.referenceNumber: 'Reference Number',
  StatementField.merchantName: 'Merchant Name',
  StatementField.amount: 'Amount',
};

// Where each recognised field sits in one particular file's header row.
class HeaderMap {
  const HeaderMap({
    required this.valid,
    required this.status,
    required this.dialect,
    required this.indexes,
  });

  final bool valid;
  final String status; // human-readable, surfaced when valid is false
  final String dialect;
  final Map<StatementField, int> indexes;

  int? indexOf(StatementField field) => indexes[field];
}

// A leading BOM survives utf8.decode and would otherwise make the first header
// cell unmatchable. Quotes can survive CSV parsing when a field was quoted
// twice over.
String _normalizeHeader(String cell) => cell
    .replaceAll('﻿', '')
    .replaceAll('"', '')
    .replaceAll("'", '')
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ');

HeaderMap mapHeader(List<String> headerCells) {
  final indexes = <StatementField, int>{};
  for (var i = 0; i < headerCells.length; i++) {
    final field = _aliases[_normalizeHeader(headerCells[i])];
    // First occurrence wins, so a duplicated column can't shadow the real one.
    if (field != null) indexes.putIfAbsent(field, () => i);
  }

  final missing = _required.where((f) => !indexes.containsKey(f)).toList();
  if (missing.isNotEmpty) {
    final names = missing.map((f) => _fieldLabels[f]).join(', ');
    return HeaderMap(
      valid: false,
      status: "This file doesn't look like a bank statement — "
          'missing column: $names',
      dialect: 'unknown',
      indexes: const {},
    );
  }

  // The suffix records which header variant matched, not a different bank.
  final usedTransactionDate = headerCells.any(
    (c) => _normalizeHeader(c) == 'transaction date',
  );

  return HeaderMap(
    valid: true,
    status: 'Recognised statement columns',
    dialect: usedTransactionDate ? 'capital-one-b' : 'capital-one-a',
    indexes: indexes,
  );
}
