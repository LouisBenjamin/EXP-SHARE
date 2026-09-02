import 'package:decimal/decimal.dart';
import 'package:tally/core/dates.dart';
import 'package:tally/features/expenses/split_logic.dart';

// Turning reviewed statement rows into the payload the import RPC expects.
//
// The money maths is not re-implemented here: every row goes through
// computeSplits, the same function both expense forms use, so there is exactly
// one definition of what an equal or percentage split means.

// One row as the review screen sees it.
class ReviewRow {
  const ReviewRow({
    required this.fingerprint,
    required this.description,
    required this.occurredOn,
    required this.amount,
    required this.selected,
    required this.alreadyImported,
    this.categoryId,
  });

  final String fingerprint;
  final String description;
  final DateTime occurredOn;
  final Decimal amount;
  final bool selected;
  final bool alreadyImported;
  final String? categoryId;

  // A row already in the group can be shown, but never re-promoted.
  bool get canImport => !alreadyImported;

  ReviewRow copyWith({bool? selected, String? categoryId}) => ReviewRow(
        fingerprint: fingerprint,
        description: description,
        occurredOn: occurredOn,
        amount: amount,
        selected: selected ?? this.selected,
        alreadyImported: alreadyImported,
        categoryId: categoryId ?? this.categoryId,
      );
}

// One expense to create, with its splits already resolved.
class PlannedExpense {
  const PlannedExpense({
    required this.fingerprint,
    required this.amount,
    required this.description,
    required this.occurredOnIso,
    required this.splits,
    this.categoryId,
  });

  final String fingerprint;
  final Decimal amount;
  final String description;
  final String occurredOnIso;
  final List<Split> splits;
  final String? categoryId;
}

class ImportPlan {
  const ImportPlan({
    required this.valid,
    required this.status,
    required this.items,
  });

  final bool valid;
  final String status;
  final List<PlannedExpense> items;

  static const _empty = <PlannedExpense>[];

  static ImportPlan _invalid(String status) =>
      ImportPlan(valid: false, status: status, items: _empty);
}

// [splitType] is 'equal' or 'percent' only. Per-row exact amounts are
// deliberately unsupported: an exact split is defined against one total, so it
// cannot be applied across rows with different totals.
ImportPlan buildImportPlan({
  required List<ReviewRow> rows,
  required String splitType,
  required List<String> orderedMemberIds,
  required Set<String> participants,
  required Map<String, Decimal> percent,
}) {
  final selected = rows.where((r) => r.selected).toList();

  if (selected.isEmpty) {
    return ImportPlan._invalid('Select at least one transaction');
  }
  if (participants.isEmpty) {
    return ImportPlan._invalid('Select at least one participant');
  }

  final blocked = selected.where((r) => !r.canImport).toList();
  if (blocked.isNotEmpty) {
    return ImportPlan._invalid(
      '${blocked.first.description} is already imported',
    );
  }

  final items = <PlannedExpense>[];
  for (final row in selected) {
    final outcome = computeSplits(
      splitType: splitType,
      orderedMemberIds: orderedMemberIds,
      selected: participants,
      amount: row.amount,
      exact: const {},
      percent: percent,
    );

    // Surface the split rule's own wording, prefixed with the row it failed
    // on, rather than inventing a second vocabulary for the same problem.
    if (!outcome.valid) {
      return ImportPlan._invalid('${row.description}: ${outcome.status}');
    }

    items.add(
      PlannedExpense(
        fingerprint: row.fingerprint,
        amount: row.amount,
        description: row.description,
        occurredOnIso: isoDate(row.occurredOn),
        splits: outcome.splits,
        categoryId: row.categoryId,
      ),
    );
  }

  final n = items.length;
  return ImportPlan(
    valid: true,
    status: 'Ready to import $n expense${n == 1 ? '' : 's'}',
    items: items,
  );
}
