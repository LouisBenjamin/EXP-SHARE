import 'package:decimal/decimal.dart';
import 'package:exp_share/features/expenses/split_logic.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String s) => Decimal.parse(s);

SplitOutcome run({
  required String type,
  List<String> members = const ['a', 'b', 'c'],
  Set<String>? selected,
  String amount = '90',
  Map<String, Decimal> exact = const {},
  Map<String, Decimal> percent = const {},
}) {
  return computeSplits(
    splitType: type,
    orderedMemberIds: members,
    selected: selected ?? members.toSet(),
    amount: d(amount),
    exact: exact,
    percent: percent,
  );
}

void main() {
  group('guards', () {
    test('no participants selected is invalid', () {
      final r = run(type: 'equal', selected: {});
      expect(r.valid, isFalse);
      expect(r.status, contains('participant'));
    });

    test('zero / negative amount is invalid', () {
      expect(run(type: 'equal', amount: '0').valid, isFalse);
      expect(run(type: 'equal', amount: '-5').valid, isFalse);
    });
  });

  group('equal', () {
    test('splits evenly and is always valid with amount + participants', () {
      final r = run(type: 'equal', amount: '90');
      expect(r.valid, isTrue);
      expect(r.splits.map((s) => s.shareAmount),
          [d('30'), d('30'), d('30')]);
    });

    test('only selected participants are included', () {
      final r = run(type: 'equal', selected: {'a', 'c'}, amount: '10');
      expect(r.splits.map((s) => s.memberId), ['a', 'c']);
      expect(r.splits.map((s) => s.shareAmount).reduce((x, y) => x + y),
          d('10'));
    });

    test('remainder handling keeps the sum exact', () {
      final r = run(type: 'equal', amount: '100');
      expect(r.splits.map((s) => s.shareAmount).reduce((x, y) => x + y),
          d('100'));
    });
  });

  group('exact', () {
    test('valid when the entered amounts sum to the total', () {
      final r = run(type: 'exact', amount: '90', exact: {
        'a': d('40'),
        'b': d('30'),
        'c': d('20'),
      });
      expect(r.valid, isTrue);
      expect(r.status, contains('add up'));
    });

    test('invalid when they do not sum to the total', () {
      final r = run(type: 'exact', amount: '90', exact: {
        'a': d('40'),
        'b': d('30'),
        'c': d('10'),
      });
      expect(r.valid, isFalse);
      expect(r.status, contains('80'));
    });

    test('missing entries are treated as zero', () {
      final r = run(type: 'exact', amount: '90', exact: {'a': d('90')});
      expect(r.valid, isTrue);
      expect(r.splits.firstWhere((s) => s.memberId == 'b').shareAmount,
          Decimal.zero);
    });
  });

  group('percent', () {
    test('valid when percentages sum to 100', () {
      final r = run(type: 'percent', amount: '90', percent: {
        'a': d('50'),
        'b': d('25'),
        'c': d('25'),
      });
      expect(r.valid, isTrue);
      expect(r.splits.map((s) => s.shareAmount).reduce((x, y) => x + y),
          d('90'));
    });

    test('last participant absorbs the rounding remainder', () {
      // 33.33 / 33.33 / 33.34  ->  amounts still total exactly.
      final r = run(type: 'percent', amount: '100', percent: {
        'a': d('33.33'),
        'b': d('33.33'),
        'c': d('33.34'),
      });
      expect(r.valid, isTrue);
      expect(r.splits.map((s) => s.shareAmount).reduce((x, y) => x + y),
          d('100'));
    });

    test('invalid when percentages do not sum to 100', () {
      final r = run(type: 'percent', amount: '90', percent: {
        'a': d('50'),
        'b': d('25'),
        'c': d('20'),
      });
      expect(r.valid, isFalse);
      expect(r.status, contains('100%'));
    });

    test('sharePercent is recorded on each split', () {
      final r = run(type: 'percent', amount: '90', percent: {
        'a': d('50'),
        'b': d('30'),
        'c': d('20'),
      });
      expect(r.splits.firstWhere((s) => s.memberId == 'a').sharePercent,
          d('50'));
    });
  });
}
