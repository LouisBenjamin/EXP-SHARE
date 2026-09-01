import 'package:tally/features/import/data/import_repository.dart';
import 'package:tally/features/import/data/merchant_rules_repository.dart';
import 'package:tally/models/merchant_rule.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final merchantRulesProvider =
    FutureProvider.family<List<MerchantRule>, String>((ref, groupId) {
  return MerchantRulesRepository().fetchRules(groupId: groupId);
});

// The already-promoted half of deduplication. Fetched rather than remembered
// locally on purpose: a roommate importing the same shared-card statement from
// their own phone has no local record of what this device did, but they do see
// the group's fingerprints.
final importedFingerprintsProvider =
    FutureProvider.family<Set<String>, String>((ref, groupId) {
  return ImportRepository().fetchImportedFingerprints(groupId: groupId);
});
