import 'package:exp_share/features/balances/data/balances_repository.dart';
import 'package:exp_share/models/member_balance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Net balance per member for a group.
// Invalidate after any expense or settlement change.
final balancesProvider = FutureProvider.family<List<MemberBalance>, String>(
  (ref, groupId) => BalancesRepository().fetchBalances(groupId: groupId),
);
