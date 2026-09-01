import 'package:decimal/decimal.dart';

// One row of the group_balances view.
// net > 0  => this member is owed money (others owe them)
// net < 0  => this member owes money
class MemberBalance {
  const MemberBalance({required this.memberId, required this.net});

  final String memberId;
  final Decimal net;

  factory MemberBalance.fromJson(Map<String, dynamic> json) => MemberBalance(
        memberId: json['member_id'] as String,
        net: Decimal.parse((json['net'] ?? '0').toString()),
      );
}
