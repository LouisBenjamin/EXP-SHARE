import 'package:decimal/decimal.dart';

// One row of expense_splits: how much a single member owes on an expense.
class ExpenseSplit {
  const ExpenseSplit({
    required this.memberId,
    required this.shareAmount,
    this.sharePercent,
  });

  final String memberId;
  final Decimal shareAmount;
  final Decimal? sharePercent;

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) => ExpenseSplit(
        memberId: json['member_id'] as String,
        shareAmount: Decimal.parse(json['share_amount'].toString()),
        sharePercent: json['share_percent'] == null
            ? null
            : Decimal.parse(json['share_percent'].toString()),
      );
}
