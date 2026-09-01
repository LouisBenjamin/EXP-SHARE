import 'package:decimal/decimal.dart';
import 'package:exp_share/core/money.dart';

// One participant's share of an expense (or recurring template).
// sharePercent is only set for the 'percent' split type.
typedef Split = ({String memberId, Decimal shareAmount, Decimal? sharePercent});

// Result of validating the current split inputs.
class SplitOutcome {
  const SplitOutcome({
    required this.valid,
    required this.status,
    required this.splits,
  });

  final bool valid;
  final String status; // short human-readable state, e.g. "Splits add up ✓"
  final List<Split> splits;
}

// Pure split maths, shared by the one-off and recurring expense forms so the
// money rules live in exactly one place. [orderedMemberIds] fixes iteration
// order (the last selected participant absorbs any rounding remainder);
// [exact]/[percent] are the raw values entered per member for those modes.
SplitOutcome computeSplits({
  required String splitType,
  required List<String> orderedMemberIds,
  required Set<String> selected,
  required Decimal amount,
  required Map<String, Decimal> exact,
  required Map<String, Decimal> percent,
}) {
  final selectedIds =
      orderedMemberIds.where(selected.contains).toList(growable: false);

  if (selectedIds.isEmpty) {
    return const SplitOutcome(
      valid: false,
      status: 'Select at least one participant',
      splits: [],
    );
  }
  if (amount <= Decimal.zero) {
    return const SplitOutcome(
      valid: false,
      status: 'Enter an amount',
      splits: [],
    );
  }

  switch (splitType) {
    case 'exact':
      var sum = Decimal.zero;
      final splits = <Split>[];
      for (final id in selectedIds) {
        final v = exact[id] ?? Decimal.zero;
        sum += v;
        splits.add((memberId: id, shareAmount: v, sharePercent: null));
      }
      final ok = sum == amount;
      return SplitOutcome(
        valid: ok,
        status: ok
            ? 'Splits add up ✓'
            : 'Assigned ${formatCurrency(sum)} of ${formatCurrency(amount)}',
        splits: splits,
      );

    case 'percent':
      var pctSum = Decimal.zero;
      for (final id in selectedIds) {
        pctSum += percent[id] ?? Decimal.zero;
      }
      final ok = pctSum == Decimal.fromInt(100);
      final splits = <Split>[];
      var assigned = Decimal.zero;
      for (var i = 0; i < selectedIds.length; i++) {
        final id = selectedIds[i];
        final p = percent[id] ?? Decimal.zero;
        // Last participant absorbs the rounding remainder for an exact sum.
        final share = i == selectedIds.length - 1
            ? amount - assigned
            : percentShare(amount, p);
        if (i != selectedIds.length - 1) assigned += share;
        splits.add((memberId: id, shareAmount: share, sharePercent: p));
      }
      return SplitOutcome(
        valid: ok,
        status: ok ? 'Percentages add up ✓' : 'Total $pctSum% (need 100%)',
        splits: splits,
      );

    default: // equal
      final shares = splitEqually(amount, selectedIds.length);
      final splits = [
        for (var i = 0; i < selectedIds.length; i++)
          (memberId: selectedIds[i], shareAmount: shares[i], sharePercent: null),
      ];
      return SplitOutcome(valid: true, status: 'Split equally', splits: splits);
  }
}
