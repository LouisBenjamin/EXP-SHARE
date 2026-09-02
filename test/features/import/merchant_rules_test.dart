import 'package:tally/features/import/logic/merchant_rules.dart';
import 'package:tally/models/merchant_rule.dart';
import 'package:flutter_test/flutter_test.dart';

MerchantRule rule(
  String pattern, {
  String id = 'r1',
  String matchType = 'contains',
  String action = 'share',
  int priority = 100,
  String? categoryId = 'groceries',
}) =>
    MerchantRule(
      id: id,
      groupId: 'g1',
      pattern: pattern,
      matchType: matchType,
      action: action,
      priority: priority,
      categoryId: categoryId,
    );

RuleHit match(
  String merchant, {
  String category = '',
  List<MerchantRule> rules = const [],
}) =>
    matchMerchantRule(
      merchantNormalized: merchant,
      merchantCategoryDescription: category,
      rules: rules,
    );

void main() {
  group('matching', () {
    // The reason matching is substring-based: the same warehouse appears under
    // two different store codes.
    test('one contains rule covers both Costco store numbers', () {
      final rules = [rule('COSTCO WHOLESALE')];
      expect(match('COSTCO WHOLESALE W515', rules: rules).categoryId, 'groceries');
      expect(match('COSTCO WHOLESALE W521', rules: rules).categoryId, 'groceries');
    });

    test('contains matches mid-string', () {
      expect(match('SP+AFF* CHIMERA GAMING', rules: [rule('CHIMERA')]).ruleId, 'r1');
    });

    test('prefix does not match mid-string', () {
      final rules = [rule('CHIMERA', matchType: 'prefix')];
      expect(match('SP+AFF* CHIMERA GAMING', rules: rules).status, 'Untagged');
      expect(match('CHIMERA GAMING', rules: rules).ruleId, 'r1');
    });

    test('exact requires the whole name', () {
      final rules = [rule('COSTCO WHOLESALE', matchType: 'exact')];
      expect(match('COSTCO WHOLESALE W515', rules: rules).status, 'Untagged');
      expect(match('COSTCO WHOLESALE', rules: rules).ruleId, 'r1');
    });

    test('a processor prefix is still matchable', () {
      expect(match('GOOGLE *SPOTIFY MUSIC', rules: [rule('GOOGLE')]).ruleId, 'r1');
      expect(match('GOOGLE *SPOTIFY MUSIC', rules: [rule('SPOTIFY')]).ruleId, 'r1');
    });

    test('an empty pattern never matches', () {
      expect(match('ANYTHING', rules: [rule('   ')]).status, 'Untagged');
    });
  });

  group('precedence', () {
    test('lower priority wins', () {
      final rules = [
        rule('COSTCO', id: 'general', priority: 200, categoryId: 'shopping'),
        rule('COSTCO', id: 'specific', priority: 10, categoryId: 'groceries'),
      ];
      expect(match('COSTCO WHOLESALE W515', rules: rules).ruleId, 'specific');
    });

    // So the user can add a narrow rule without reasoning about numbers.
    test('on equal priority the longer pattern wins', () {
      final rules = [
        rule('COSTCO', id: 'broad', categoryId: 'shopping'),
        rule('COSTCO GAS', id: 'narrow', categoryId: 'transport'),
      ];
      expect(match('COSTCO GAS W521', rules: rules).ruleId, 'narrow');
      expect(match('COSTCO WHOLESALE W521', rules: rules).ruleId, 'broad');
    });
  });

  group('category description fallback', () {
    test('matches the category when the merchant name gives nothing away', () {
      final hit = match(
        'AU MOULIN DU TEMPS',
        category: 'Eating Places and Restaurants',
        rules: [rule('RESTAURANT', categoryId: 'food')],
      );
      expect(hit.categoryId, 'food');
    });

    test('the merchant name takes precedence over the category', () {
      final hit = match(
        'COSTCO WHOLESALE W515',
        category: 'Eating Places and Restaurants',
        rules: [
          rule('COSTCO', id: 'byName', categoryId: 'groceries'),
          rule('RESTAURANT', id: 'byCategory', categoryId: 'food'),
        ],
      );
      expect(hit.ruleId, 'byName');
    });
  });

  group('skip rules', () {
    test('a skip rule marks the row as not shared', () {
      final hit = match(
        'SP SILVER GOBLIN',
        rules: [rule('SILVER GOBLIN', action: 'skip', categoryId: null)],
      );
      expect(hit.isSkip, isTrue);
    });
  });

  group('no match', () {
    test('is still offered, untagged, rather than hidden', () {
      final hit = match('SOME NEW SHOP', rules: [rule('COSTCO')]);
      expect(hit.action, 'share');
      expect(hit.status, 'Untagged');
      expect(hit.categoryId, isNull);
      expect(hit.ruleId, isNull);
    });

    test('an empty rule set tags nothing', () {
      expect(match('COSTCO WHOLESALE W515').status, 'Untagged');
    });
  });
}
