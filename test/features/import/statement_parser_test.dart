import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:tally/features/import/logic/statement_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String s) => Decimal.parse(s);

const _headerA =
    'Date,Posted Date,Reference Number,Activity Type,Activity Status,'
    'Card Number,Merchant Category Description,Merchant Name,Merchant City,'
    'Merchant State or Province,Merchant Country Code,Merchant Postal Code,'
    'Amount,Rewards,Name on Card';

// Rows copied from a real export.
const _rowCostco = '2026-08-27,2026-08-28,"55134426239800194245854",TRANS,'
    'APPROVED,************9794,Wholesale Club with or without membership fee ,'
    'COSTCO WHOLESALE W515,MONTREAL,QC,CAN,H3K2C3,\$358.94,,BENJAMIN DUROCHER';

const _rowRestaurant = '2026-08-30,2026-08-31,"55181366242380664636432",TRANS,'
    'APPROVED,************9794,Eating Places and Restaurants,'
    'AU MOULIN DU TEMPS,NAMUR,QC,CAN,J0V 1N0,\$66.82,,BENJAMIN DUROCHER';

const _rowPayment = '2026-08-02,2026-08-04,"40828MBLE-241127-225678",TRANS,'
    'APPROVED,************9794,,PAYMENT THANK YOU,,,,,-\$1000.00,,'
    'BENJAMIN DUROCHER';

StatementParseResult run(List<String> rows, {String header = _headerA}) =>
    parseStatementCsv([header, ...rows].join('\n'));

void main() {
  group('header handling', () {
    test('parses the Date/Activity Status export', () {
      final result = run([_rowCostco, _rowRestaurant]);
      expect(result.valid, isTrue);
      expect(result.dialect, 'capital-one-a');
      expect(result.transactions, hasLength(2));
    });

    // Same data, different export screen: BOM, renamed headers, every field
    // quoted. It must produce the same transactions.
    test('parses the fully-quoted Transaction Date export with a BOM', () {
      const header = '﻿"Transaction Date","Posted Date","Reference Number",'
          '"Activity Type","Status","Card Number","Merchant Category",'
          '"Merchant Name","Merchant City","Merchant State/Province",'
          '"Merchant Country","Merchant Zip","Amount","Rewards","Name on Card"';
      const row = '"2025-06-10","2025-06-11","""55259565161291612668974""",'
          '"TRANS","APPROVED","************9794",'
          '"Miscellaneous and Specialty Retail Stores","TOPDECK HERO","LAVAL",'
          '"QC","CAN","H7L 2Y8","\$43.00","","BENJAMIN DUROCHER"';

      final result = parseStatementCsv('$header\n$row');
      expect(result.valid, isTrue);
      expect(result.dialect, 'capital-one-b');
      expect(result.transactions, hasLength(1));

      final txn = result.transactions.single;
      expect(txn.merchantName, 'TOPDECK HERO');
      expect(txn.amount, d('43.00'));
      expect(txn.occurredOn, DateTime(2025, 6, 10));
      // The doubled quotes must not survive, or dedup breaks across exports.
      expect(txn.reference, isNot(contains('"')));
      expect(txn.reference, '55259565161291612668974');
    });

    test('rejects a file whose header is not a statement', () {
      final result = parseStatementCsv('name,email\nBen,ben@example.com');
      expect(result.valid, isFalse);
      expect(result.status, contains('missing column'));
    });

    test('rejects an empty file', () {
      expect(parseStatementCsv('').valid, isFalse);
      expect(parseStatementCsv('   \n  ').valid, isFalse);
    });
  });

  group('row parsing', () {
    test('reads amount, date, merchant and category', () {
      final txn = run([_rowCostco]).transactions.single;
      expect(txn.amount, d('358.94'));
      expect(txn.occurredOn, DateTime(2026, 8, 27));
      expect(txn.postedOn, DateTime(2026, 8, 28));
      expect(txn.merchantName, 'COSTCO WHOLESALE W515');
      expect(txn.merchantNormalized, 'COSTCO WHOLESALE W515');
      expect(txn.merchantCategory, contains('Wholesale Club'));
      expect(txn.cardLast4, '9794');
    });

    // The transaction date is the one that goes on the expense: the posted
    // date is a settlement artifact and can land in a different month.
    test('keeps the transaction date distinct from the posted date', () {
      final txn = run([_rowRestaurant]).transactions.single;
      expect(txn.occurredOn, DateTime(2026, 8, 30));
      expect(txn.postedOn, DateTime(2026, 8, 31));
    });

    test('does not mangle a 23-digit reference number', () {
      // Longer than an int64, so a numeric CSV parse would silently corrupt it.
      final txn = run([_rowRestaurant]).transactions.single;
      expect(txn.reference, '55181366242380664636432');
    });

    test('tolerates CRLF line endings and a trailing blank line', () {
      final result = parseStatementCsv('$_headerA\r\n$_rowCostco\r\n\r\n');
      expect(result.valid, isTrue);
      expect(result.transactions, hasLength(1));
    });
  });

  group('credits', () {
    // expenses.amount has check (amount > 0), so a payment could never become
    // a shared expense. Dropping it here keeps it out of the review list too.
    test('drops payments and refunds without failing the import', () {
      final result = run([_rowCostco, _rowPayment, _rowRestaurant]);
      expect(result.valid, isTrue);
      expect(result.transactions, hasLength(2));
      expect(result.skippedCredits, 1);
      expect(
        result.transactions.map((t) => t.merchantName),
        isNot(contains('PAYMENT THANK YOU')),
      );
    });

    test('mentions hidden payments in the summary', () {
      expect(run([_rowCostco, _rowPayment]).status, contains('payment/refund'));
    });

    test('every kept amount is positive', () {
      for (final txn in run([_rowCostco, _rowPayment]).transactions) {
        expect(txn.amount > Decimal.zero, isTrue);
      }
    });
  });

  group('bad rows', () {
    // One broken row must not cost the whole statement.
    test('records an issue and keeps parsing the rest', () {
      const noAmount = '2026-08-26,2026-08-27,"999",TRANS,APPROVED,'
          '************9794,Cat,SOME SHOP,MTL,QC,CAN,H3K,,,BENJAMIN DUROCHER';

      final result = run([_rowCostco, noAmount, _rowRestaurant]);
      expect(result.valid, isTrue);
      expect(result.transactions, hasLength(2));
      expect(result.issues, hasLength(1));
      expect(result.issues.single.message, contains('amount'));
      expect(result.status, contains('skipped'));
    });

    test('records an issue for an unreadable date', () {
      const badDate = 'not-a-date,2026-08-27,"998",TRANS,APPROVED,'
          '************9794,Cat,SOME SHOP,MTL,QC,CAN,H3K,\$5.00,,BEN';
      final result = run([badDate]);
      expect(result.transactions, isEmpty);
      expect(result.issues.single.message, contains('date'));
    });

    test('records an issue for a missing reference number', () {
      const noRef = '2026-08-26,2026-08-27,,TRANS,APPROVED,'
          '************9794,Cat,SOME SHOP,MTL,QC,CAN,H3K,\$5.00,,BEN';
      final result = run([noRef]);
      expect(result.transactions, isEmpty);
      expect(result.issues.single.message, contains('reference'));
    });

    test('skips rows that are not approved yet', () {
      const pending = '2026-08-26,2026-08-27,"997",TRANS,PENDING,'
          '************9794,Cat,SOME SHOP,MTL,QC,CAN,H3K,\$5.00,,BEN';
      final result = run([_rowCostco, pending]);
      expect(result.transactions, hasLength(1));
      expect(result.status, contains('not yet approved'));
    });

    test('keeps only the first of a reference repeated within one file', () {
      final result = run([_rowCostco, _rowCostco]);
      expect(result.transactions, hasLength(1));
      expect(result.issues.single.message, contains('duplicate'));
    });
  });

  group('parseStatement dispatch', () {
    test('routes a .csv file to the CSV parser', () {
      final bytes = Uint8List.fromList(utf8.encode('$_headerA\n$_rowCostco'));
      final result = parseStatement('transactions.csv', bytes);
      expect(result.valid, isTrue);
      expect(result.transactions, hasLength(1));
    });

    // PDF support is phase 2; until then this must fail with advice, not a
    // stack trace.
    test('refuses a file type no parser claims', () {
      final result = parseStatement('statement.pdf', Uint8List(0));
      expect(result.valid, isFalse);
      expect(result.status, contains('CSV'));
    });
  });
}
