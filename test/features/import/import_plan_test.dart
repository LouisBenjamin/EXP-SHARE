import 'package:decimal/decimal.dart';
import 'package:tally/features/import/logic/import_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String s) => Decimal.parse(s);

ReviewRow row(
  String amount, {
  String fingerprint = 'f1',
  String description = 'COSTCO WHOLESALE',
  bool selected = true,
  bool alreadyImported = false,
  String? categoryId,
  DateTime? occurredOn,
}) =>
    ReviewRow(
      fingerprint: fingerprint,
      description: description,
      occurredOn: occurredOn ?? DateTime(2026, 8, 27),
      amount: d(amount),
      selected: selected,
      alreadyImported: alreadyImported,
      categoryId: categoryId,
    );

ImportPlan run({
  required List<ReviewRow> rows,
  String splitType = 'equal',
  List<String> members = const ['a', 'b'],
  Set<String>? participants,
  Map<String, Decimal> percent = const {},
}) =>
    buildImportPlan(
      rows: rows,
      splitType: splitType,
      orderedMemberIds: members,
      participants: participants ?? {'a', 'b'},
      percent: percent,
    );

void main() {
  group('guards', () {
    test('nothing selected', () {
      final plan = run(rows: [row('10', selected: false)]);
      expect(plan.valid, isFalse);
      expect(plan.status, contains('Select at least one transaction'));
    });

    test('no participants', () {
      final plan = run(rows: [row('10')], participants: {});
      expect(plan.valid, isFalse);
      expect(plan.status, contains('participant'));
    });

    // The server rejects these too, but failing here means the user sees the
    // merchant name instead of a Postgres error in a snackbar.
    test('an already-imported row names itself', () {
      final plan = run(
        rows: [row('10', description: 'AU MOULIN DU TEMPS', alreadyImported: true)],
      );
      expect(plan.valid, isFalse);
      expect(plan.status, contains('AU MOULIN DU TEMPS'));
      expect(plan.status, contains('already imported'));
    });

    test('unselected rows are ignored, not blocking', () {
      final plan = run(rows: [
        row('10', fingerprint: 'f1'),
        row('20', fingerprint: 'f2', alreadyImported: true, selected: false),
      ]);
      expect(plan.valid, isTrue);
      expect(plan.items, hasLength(1));
    });
  });

  group('equal split', () {
    test('plans one expense per selected row', () {
      final plan = run(rows: [
        row('90', fingerprint: 'f1'),
        row('10', fingerprint: 'f2'),
      ]);
      expect(plan.valid, isTrue);
      expect(plan.items, hasLength(2));
      expect(plan.status, 'Ready to import 2 expenses');
    });

    test('singular wording for one row', () {
      expect(run(rows: [row('90')]).status, 'Ready to import 1 expense');
    });

    test('each row splits across the participants', () {
      final plan = run(rows: [row('90')], members: ['a', 'b', 'c'], participants: {'a', 'b', 'c'});
      expect(plan.items.single.splits.map((s) => s.shareAmount),
          [d('30'), d('30'), d('30')]);
    });

    test('splits sum back to each row amount, penny-perfect', () {
      for (final amount in ['0.01', '10', '66.82', '358.94', '1000.03']) {
        final plan = run(
          rows: [row(amount)],
          members: ['a', 'b', 'c'],
          participants: {'a', 'b', 'c'},
        );
        final total = plan.items.single.splits
            .map((s) => s.shareAmount)
            .reduce((a, b) => a + b);
        expect(total, d(amount), reason: amount);
      }
    });

    test('only the chosen participants are charged', () {
      final plan = run(
        rows: [row('90')],
        members: ['a', 'b', 'c'],
        participants: {'a', 'c'},
      );
      expect(plan.items.single.splits.map((s) => s.memberId), ['a', 'c']);
    });
  });

  group('percent split', () {
    test('scales per row and still sums exactly', () {
      final plan = run(
        rows: [row('100', fingerprint: 'f1'), row('66.82', fingerprint: 'f2')],
        splitType: 'percent',
        percent: {'a': d('60'), 'b': d('40')},
      );
      expect(plan.valid, isTrue);
      for (final item in plan.items) {
        final total =
            item.splits.map((s) => s.shareAmount).reduce((a, b) => a + b);
        expect(total, item.amount, reason: item.description);
      }
      expect(plan.items.first.splits.first.shareAmount, d('60'));
    });

    // computeSplits owns this rule; the plan just surfaces its wording.
    test('percentages that do not total 100 fail with the row named', () {
      final plan = run(
        rows: [row('100', description: 'TOPDECK HERO')],
        splitType: 'percent',
        percent: {'a': d('60'), 'b': d('30')},
      );
      expect(plan.valid, isFalse);
      expect(plan.status, contains('TOPDECK HERO'));
      expect(plan.status, contains('100%'));
    });
  });

  group('payload', () {
    test('carries the statement date, not today', () {
      final plan = run(rows: [row('10', occurredOn: DateTime(2026, 1, 5))]);
      expect(plan.items.single.occurredOnIso, '2026-01-05');
    });

    test('carries the fingerprint and category through', () {
      final plan = run(
        rows: [row('10', fingerprint: 'abc123', categoryId: 'groceries')],
      );
      expect(plan.items.single.fingerprint, 'abc123');
      expect(plan.items.single.categoryId, 'groceries');
    });

    test('an untagged row plans with no category', () {
      expect(run(rows: [row('10')]).items.single.categoryId, isNull);
    });
  });
}
