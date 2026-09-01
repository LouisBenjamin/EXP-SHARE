import 'package:tally/features/import/logic/csv_dialect.dart';
import 'package:flutter_test/flutter_test.dart';

// The two real header rows, verbatim from downloaded statements.
const _dialectA = [
  'Date', 'Posted Date', 'Reference Number', 'Activity Type',
  'Activity Status', 'Card Number', 'Merchant Category Description',
  'Merchant Name', 'Merchant City', 'Merchant State or Province',
  'Merchant Country Code', 'Merchant Postal Code', 'Amount', 'Rewards',
  'Name on Card',
];

const _dialectB = [
  'Transaction Date', 'Posted Date', 'Reference Number', 'Activity Type',
  'Status', 'Card Number', 'Merchant Category', 'Merchant Name',
  'Merchant City', 'Merchant State/Province', 'Merchant Country',
  'Merchant Zip', 'Amount', 'Rewards', 'Name on Card',
];

void main() {
  group('mapHeader', () {
    test('maps the Date/Activity Status export', () {
      final header = mapHeader(_dialectA);
      expect(header.valid, isTrue);
      expect(header.dialect, 'capital-one-a');
      expect(header.indexOf(StatementField.transactionDate), 0);
      expect(header.indexOf(StatementField.referenceNumber), 2);
      expect(header.indexOf(StatementField.status), 4);
      expect(header.indexOf(StatementField.merchantCategory), 6);
      expect(header.indexOf(StatementField.merchantName), 7);
      expect(header.indexOf(StatementField.amount), 12);
    });

    test('maps the Transaction Date/Status export to the same fields', () {
      final header = mapHeader(_dialectB);
      expect(header.valid, isTrue);
      expect(header.dialect, 'capital-one-b');
      // Same logical columns, same positions, different spellings.
      expect(header.indexOf(StatementField.transactionDate), 0);
      expect(header.indexOf(StatementField.referenceNumber), 2);
      expect(header.indexOf(StatementField.status), 4);
      expect(header.indexOf(StatementField.merchantCategory), 6);
      expect(header.indexOf(StatementField.merchantName), 7);
      expect(header.indexOf(StatementField.amount), 12);
    });

    test('survives a UTF-8 BOM on the first cell', () {
      final withBom = ['﻿Transaction Date', ..._dialectB.skip(1)];
      final header = mapHeader(withBom);
      expect(header.valid, isTrue);
      expect(header.indexOf(StatementField.transactionDate), 0);
    });

    test('survives quotes left on header cells', () {
      final quoted = _dialectB.map((c) => '"$c"').toList();
      expect(mapHeader(quoted).valid, isTrue);
    });

    test('ignores case and extra whitespace', () {
      final messy = ['  date ', 'REFERENCE   NUMBER', 'merchant name', 'AmOuNt'];
      final header = mapHeader(messy);
      expect(header.valid, isTrue);
      expect(header.indexOf(StatementField.amount), 3);
    });

    // A statement that gains columns must still import — that is the whole
    // reason the header is mapped by name instead of by position.
    test('ignores unknown extra columns', () {
      final extended = [..._dialectA, 'Foreign Currency', 'Exchange Rate'];
      final header = mapHeader(extended);
      expect(header.valid, isTrue);
      expect(header.indexOf(StatementField.amount), 12);
    });

    test('reports which required column is missing', () {
      final noAmount = _dialectA.where((c) => c != 'Amount').toList();
      final header = mapHeader(noAmount);
      expect(header.valid, isFalse);
      expect(header.status, contains('Amount'));
    });

    test('rejects a file that is not a statement at all', () {
      final header = mapHeader(['name', 'email', 'phone']);
      expect(header.valid, isFalse);
      expect(header.dialect, 'unknown');
    });

    test('optional columns are simply absent rather than fatal', () {
      final minimal = ['Date', 'Reference Number', 'Merchant Name', 'Amount'];
      final header = mapHeader(minimal);
      expect(header.valid, isTrue);
      expect(header.indexOf(StatementField.postedDate), isNull);
      expect(header.indexOf(StatementField.cardNumber), isNull);
    });
  });
}
