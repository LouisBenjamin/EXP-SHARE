import 'package:tally/core/supabase_client.dart';
import 'package:tally/models/merchant_rule.dart';

class MerchantRulesRepository {
  Future<List<MerchantRule>> fetchRules({required String groupId}) async {
    final data = await supabase
        .from('merchant_rules')
        .select()
        .eq('group_id', groupId)
        .order('priority')
        .order('pattern');
    return (data as List)
        .map((e) => MerchantRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Patterns are stored uppercased so matching never has to case-fold the
  // stored side, and so the unique (group_id, pattern, match_type) constraint
  // actually catches a re-added duplicate.
  Future<void> createRule({
    required String groupId,
    required String pattern,
    required String matchType,
    required String action,
    String? categoryId,
    int priority = 100,
  }) async {
    await supabase.from('merchant_rules').insert({
      'group_id': groupId,
      'pattern': pattern.trim().toUpperCase(),
      'match_type': matchType,
      'action': action,
      'category_id': categoryId,
      'priority': priority,
      'created_by': supabase.auth.currentUser!.id,
    });
  }

  Future<void> updateRule({
    required String id,
    required String pattern,
    required String matchType,
    required String action,
    String? categoryId,
    int priority = 100,
  }) async {
    await supabase.from('merchant_rules').update({
      'pattern': pattern.trim().toUpperCase(),
      'match_type': matchType,
      'action': action,
      'category_id': categoryId,
      'priority': priority,
    }).eq('id', id);
  }

  Future<void> deleteRule({required String id}) async {
    await supabase.from('merchant_rules').delete().eq('id', id);
  }
}
