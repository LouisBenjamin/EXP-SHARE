import 'package:decimal/decimal.dart';

// One row of the my_group_summaries view: a group plus the caller's own net
// balance in it, so the groups list can show a status line without an N+1
// balances fetch per card.
//
// net > 0 => the caller is owed money; net < 0 => the caller owes money.
class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.photoUrl,
    required this.myMemberId,
    required this.myNet,
  });

  final String id;
  final String name;
  final String joinCode;
  final String? photoUrl;
  final String myMemberId;
  final Decimal myNet;

  factory GroupSummary.fromJson(Map<String, dynamic> json) => GroupSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        joinCode: json['join_code'] as String,
        photoUrl: json['photo_url'] as String?,
        myMemberId: json['my_member_id'] as String,
        myNet: Decimal.parse((json['my_net'] ?? '0').toString()),
      );
}
