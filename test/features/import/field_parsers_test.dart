import 'package:decimal/decimal.dart';
import 'package:tally/features/import/logic/field_parsers.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('parseStatementAmount', () {
    test('reads the plain export format', () {
      expect(parseStatementAmount(r'$66.82'), d('66.82'));
      expect(parseStatementAmount(r'$17.25'), d('17.25'));
      expect(parseStatementAmount('66.82'), d('66.82'));
    });

    test('reads a negative with the sign before the currency symbol', () {
      // How payments actually appear: 'PAYMENT THANK YOU  -$1000.00'.
      expect(parseStatementAmount(r'-$1000.00'), d('-1000.00'));
      expect(parseStatementAmount(r'-$6.21'), d('-6.21'));
    });

    test('reads thousands separators', () {
      expect(parseStatementAmount(r'$1,234.56'), d('1234.56'));
      expect(parseStatementAmount(r'$1,000,000.00'), d('1000000.00'));
    });

    test('reads accounting parentheses as negative', () {
      expect(parseStatementAmount(r'($5.00)'), d('-5.00'));
    });

    test('keeps full precision rather than going through a double', () {
      expect(parseStatementAmount(r'$0.07'), d('0.07'));
      expect(parseStatementAmount(r'$358.94'), d('358.94'));
    });

    test('returns null on anything unreadable', () {
      for (final bad in ['', '   ', 'n/a', 'abc', r'$', '--5']) {
        expect(parseStatementAmount(bad), isNull, reason: bad);
      }
    });
  });

  group('normalizeReference', () {
    test('leaves a plain reference alone', () {
      expect(
        normalizeReference('55181366242380664636432'),
        '55181366242380664636432',
      );
    });

    test('strips the quotes one export leaves attached', () {
      expect(
        normalizeReference('"55259565161291612668974"'),
        '55259565161291612668974',
      );
    });

    test('preserves non-numeric references', () {
      expect(
        normalizeReference('40828MBLE-241127-225678'),
        '40828MBLE-241127-225678',
      );
    });

    test('strips surrounding and internal whitespace', () {
      expect(normalizeReference('  123 456 '), '123456');
    });
  });

  group('parseStatementDate', () {
    test('reads the ISO form every real export uses', () {
      expect(parseStatementDate('2026-08-30'), DateTime(2026, 8, 30));
      expect(parseStatementDate('"2025-06-10"'), DateTime(2025, 6, 10));
    });

    test('reads year-first with slashes', () {
      expect(parseStatementDate('2026/08/30'), DateTime(2026, 8, 30));
    });

    test('defaults ambiguous slash dates to month-first', () {
      expect(parseStatementDate('08/30/2026'), DateTime(2026, 8, 30));
      expect(parseStatementDate('01/02/2026'), DateTime(2026, 1, 2));
    });

    test('switches to day-first when the first component exceeds 12', () {
      expect(parseStatementDate('30/08/2026'), DateTime(2026, 8, 30));
    });

    test('reads a named month', () {
      expect(parseStatementDate('Aug 30, 2026'), DateTime(2026, 8, 30));
      expect(parseStatementDate('Sep 1 2026'), DateTime(2026, 9, 1));
    });

    test('returns null rather than rolling an impossible date over', () {
      for (final bad in ['2026-13-45', '2026-02-30', '', 'not a date', '13/13/2026']) {
        expect(parseStatementDate(bad), isNull, reason: bad);
      }
    });
  });

  group('normalizeMerchant', () {
    test('uppercases and collapses whitespace only', () {
      expect(normalizeMerchant('Cars on Booking'), 'CARS ON BOOKING');
      expect(normalizeMerchant('  COSTCO   WHOLESALE  '), 'COSTCO WHOLESALE');
    });

    // Destroying the prefix here would make a 'GOOGLE' rule impossible.
    test('preserves processor prefixes so they stay matchable', () {
      expect(normalizeMerchant('GOOGLE *Spotify Music'), 'GOOGLE *SPOTIFY MUSIC');
      expect(normalizeMerchant('SP+AFF* CHIMERA GAMING'), 'SP+AFF* CHIMERA GAMING');
    });
  });

  group('suggestRulePattern', () {
    // The point of the whole function: one rule should cover every store.
    test('collapses store numbers so both Costcos share a rule', () {
      expect(suggestRulePattern('COSTCO WHOLESALE W515'), 'COSTCO WHOLESALE');
      expect(suggestRulePattern('COSTCO WHOLESALE W521'), 'COSTCO WHOLESALE');
      expect(
        suggestRulePattern('COSTCO WHOLESALE W515'),
        suggestRulePattern('COSTCO WHOLESALE W521'),
      );
    });

    test('strips payment-processor prefixes', () {
      expect(suggestRulePattern('GOOGLE*MTG LIFE COUNT'), 'MTG LIFE COUNT');
      expect(suggestRulePattern('SP+AFF* CHIMERA GAMING'), 'CHIMERA GAMING');
      expect(suggestRulePattern('SP SILVER GOBLIN'), 'SP SILVER GOBLIN');
    });

    test('strips a hash-prefixed store number', () {
      expect(suggestRulePattern('SUBWAY #1234'), 'SUBWAY');
    });

    test('never returns empty, even if the name is all noise', () {
      expect(suggestRulePattern('W515'), isNotEmpty);
      expect(suggestRulePattern('SQ*'), isNotEmpty);
    });
  });
}
