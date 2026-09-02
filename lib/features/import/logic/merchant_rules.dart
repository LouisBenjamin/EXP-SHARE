import 'package:tally/models/merchant_rule.dart';

// Deciding what a statement line should become, from the group's preset rules.
//
// Matching is substring-based on a normalized merchant name rather than exact
// equality, because merchant names carry store and terminal noise: the same
// warehouse shows up as COSTCO WHOLESALE W515 and COSTCO WHOLESALE W521, and
// processors prepend their own tag (GOOGLE*MTG LIFE COUNT).

class RuleHit {
  const RuleHit({
    required this.action,
    required this.status,
    this.ruleId,
    this.categoryId,
  });

  final String action; // 'share' | 'skip'
  final String status; // short label for the row, e.g. 'COSTCO WHOLESALE'
  final String? ruleId;
  final String? categoryId;

  bool get isSkip => action == 'skip';
}

bool _matches(MerchantRule rule, String haystack) {
  final needle = rule.pattern.trim().toUpperCase();
  if (needle.isEmpty) return false;

  switch (rule.matchType) {
    case 'prefix':
      return haystack.startsWith(needle);
    case 'exact':
      return haystack == needle;
    default: // contains
      return haystack.contains(needle);
  }
}

// Lower priority first; on a tie the longer pattern wins, so a specific
// 'COSTCO GAS' rule beats a general 'COSTCO' one without the user having to
// reason about priority numbers.
List<MerchantRule> _ordered(List<MerchantRule> rules) =>
    [...rules]..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        if (byPriority != 0) return byPriority;
        return b.pattern.length.compareTo(a.pattern.length);
      });

// [merchantNormalized] must come from normalizeMerchant. The category
// description is matched as a weaker second pass so a rule like 'RESTAURANT'
// can catch merchants whose names give nothing away.
RuleHit matchMerchantRule({
  required String merchantNormalized,
  required String merchantCategoryDescription,
  required List<MerchantRule> rules,
}) {
  final ordered = _ordered(rules);

  for (final rule in ordered) {
    if (_matches(rule, merchantNormalized)) {
      return RuleHit(
        action: rule.action,
        status: rule.pattern,
        ruleId: rule.id,
        categoryId: rule.categoryId,
      );
    }
  }

  final category = merchantCategoryDescription.trim().toUpperCase();
  if (category.isNotEmpty) {
    for (final rule in ordered) {
      if (_matches(rule, category)) {
        return RuleHit(
          action: rule.action,
          status: rule.pattern,
          ruleId: rule.id,
          categoryId: rule.categoryId,
        );
      }
    }
  }

  // Unmatched rows are still offered — the user is reviewing the list anyway,
  // and silently hiding a transaction is worse than showing it untagged.
  return const RuleHit(action: 'share', status: 'Untagged');
}
