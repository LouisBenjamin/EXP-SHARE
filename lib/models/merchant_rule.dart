// A preset that decides what happens to a statement line when its merchant
// matches. Group-scoped and synced, so everyone sharing the card tags the same
// merchant the same way instead of each roommate re-tagging it every month.
//
// Rules carry merchant name patterns only — no amounts, dates, or card data.
class MerchantRule {
  const MerchantRule({
    required this.id,
    required this.groupId,
    required this.pattern,
    required this.matchType,
    required this.action,
    required this.priority,
    this.categoryId,
  });

  final String id;
  final String groupId;
  final String pattern; // uppercased merchant fragment, e.g. 'COSTCO WHOLESALE'
  final String matchType; // 'contains' | 'prefix' | 'exact'
  final String action; // 'share' = offer for import, 'skip' = never offer
  final int priority; // lower wins; ties broken by longer pattern
  final String? categoryId;

  bool get isSkip => action == 'skip';

  factory MerchantRule.fromJson(Map<String, dynamic> json) => MerchantRule(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        pattern: json['pattern'] as String,
        matchType: json['match_type'] as String? ?? 'contains',
        action: json['action'] as String? ?? 'share',
        priority: json['priority'] as int? ?? 100,
        categoryId: json['category_id'] as String?,
      );
}
