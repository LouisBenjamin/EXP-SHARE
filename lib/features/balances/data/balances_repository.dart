import 'package:tally/core/supabase_client.dart';
import 'package:tally/models/member_balance.dart';

class BalancesRepository {
  // Net balance per member from the group_balances view (RLS-scoped).
  Future<List<MemberBalance>> fetchBalances({required String groupId}) async {
    final data = await supabase
        .from('group_balances')
        .select()
        .eq('group_id', groupId);
    return (data as List)
        .map((e) => MemberBalance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Record a payment from one member to another to settle up.
  Future<void> settle({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required String amount, // Decimal.toString()
  }) async {
    await supabase.from('settlements').insert({
      'group_id': groupId,
      'from_member': fromMemberId,
      'to_member': toMemberId,
      'amount': amount,
    });
  }
}
