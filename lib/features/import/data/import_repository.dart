import 'package:tally/core/supabase_client.dart';
import 'package:tally/features/import/logic/import_plan.dart';
import 'package:tally/models/import_result.dart';

class ImportRepository {
  // The fingerprints already promoted in this group. Just opaque hashes the
  // caller can already read, and enough to mark a parsed row as "already
  // imported" before anything is written — including rows imported by someone
  // else, on another device, which is the whole point of the shared-card case.
  //
  // The SELECT policy on expenses filters deleted_at is null, so a deleted
  // expense drops out here and its transaction becomes importable again,
  // matching the partial unique index.
  Future<Set<String>> fetchImportedFingerprints({
    required String groupId,
  }) async {
    final data = await supabase
        .from('expenses')
        .select('source_fingerprint')
        .eq('group_id', groupId)
        .not('source_fingerprint', 'is', null);

    return {
      for (final row in data as List)
        (row as Map<String, dynamic>)['source_fingerprint'] as String,
    };
  }

  // Promotes reviewed rows into expenses + splits through the import_expenses
  // RPC, which re-checks membership and that each row's splits sum to its
  // amount. Money is sent as strings so numeric(12,2) precision survives the
  // JSON round-trip.
  Future<ImportResult> commitImport({
    required String groupId,
    required String payerMemberId,
    required String splitType,
    required List<PlannedExpense> items,
  }) async {
    final data = await supabase.rpc(
      'import_expenses',
      params: {
        'p_group_id': groupId,
        'p_items': [
          for (final item in items)
            {
              'fingerprint': item.fingerprint,
              'payer_member_id': payerMemberId,
              'amount': item.amount.toString(),
              'description': item.description,
              'occurred_on': item.occurredOnIso,
              'category_id': item.categoryId,
              'split_type': splitType,
              'splits': [
                for (final s in item.splits)
                  {
                    'member_id': s.memberId,
                    'share_amount': s.shareAmount.toString(),
                    if (s.sharePercent != null)
                      'share_percent': s.sharePercent.toString(),
                  },
              ],
            },
        ],
      },
    );

    return ImportResult.fromJson(data as Map<String, dynamic>);
  }
}
