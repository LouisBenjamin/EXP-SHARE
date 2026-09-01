import 'package:decimal/decimal.dart';

class RecurringExpense {
  const RecurringExpense({
    required this.id,
    required this.groupId,
    required this.payerMemberId,
    required this.amount,
    required this.currency,
    this.categoryId,
    required this.description,
    required this.splitType,
    required this.frequency,
    required this.intervalCount,
    required this.nextOccurrence,
    required this.active,
  });

  final String id;
  final String groupId;
  final String payerMemberId;
  final Decimal amount;
  final String currency;
  final String? categoryId;
  final String description;
  final String splitType;
  final String frequency; // daily | weekly | monthly
  final int intervalCount;
  final DateTime nextOccurrence;
  final bool active;

  // Human-readable cadence, e.g. "Every month" / "Every 2 weeks".
  String get cadence {
    final unit = switch (frequency) {
      'daily' => 'day',
      'weekly' => 'week',
      _ => 'month',
    };
    return intervalCount == 1 ? 'Every $unit' : 'Every $intervalCount ${unit}s';
  }

  factory RecurringExpense.fromJson(Map<String, dynamic> json) =>
      RecurringExpense(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        payerMemberId: json['payer_member_id'] as String,
        amount: Decimal.parse(json['amount'].toString()),
        currency: json['currency'] as String,
        categoryId: json['category_id'] as String?,
        description: json['description'] as String,
        splitType: json['split_type'] as String,
        frequency: json['frequency'] as String,
        intervalCount: json['interval_count'] as int,
        nextOccurrence: DateTime.parse(json['next_occurrence'] as String),
        active: json['active'] as bool,
      );
}
