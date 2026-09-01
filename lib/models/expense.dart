// Push 1: amount stored as double for simplicity.
// Push 2 will migrate to package:decimal — change the type here and update
// all callers (GroupsRepository, ExpensesRepository, add_expense_screen).
class Expense {
  const Expense({
    required this.id,
    required this.groupId,
    required this.payerMemberId,
    required this.amount,
    required this.currency,
    this.categoryId,
    required this.description,
    required this.occurredOn,
    required this.splitType,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String payerMemberId;
  final double amount;
  final String currency;
  final String? categoryId;
  final String description;
  final DateTime occurredOn;
  final String splitType;
  final String createdBy;
  final DateTime createdAt;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        payerMemberId: json['payer_member_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        categoryId: json['category_id'] as String?,
        description: json['description'] as String,
        occurredOn: DateTime.parse(json['occurred_on'] as String),
        splitType: json['split_type'] as String,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
