import 'package:decimal/decimal.dart';
import 'package:exp_share/core/supabase_client.dart';
import 'package:exp_share/models/expense.dart';

class ExpensesRepository {
  Future<List<Expense>> fetchExpenses({required String groupId}) async {
    final data = await supabase
        .from('expenses')
        .select()
        .eq('group_id', groupId)
        .isFilter('deleted_at', null)
        .order('occurred_on', ascending: false)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Creates an expense with its splits. [splits] must sum to [amount]
  // (validated in the UI). Money is Decimal, sent as strings so numeric(12,2)
  // precision survives the JSON round-trip.
  Future<void> createExpense({
    required String groupId,
    required String payerMemberId,
    required Decimal amount,
    required String description,
    String splitType = 'equal',
    String? categoryId,
    required List<({String memberId, Decimal shareAmount, Decimal? sharePercent})>
        splits,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    // Insert expense, get back the generated ID.
    final expenseRow = await supabase
        .from('expenses')
        .insert({
          'group_id': groupId,
          'payer_member_id': payerMemberId,
          'amount': amount.toString(),
          'description': description,
          'split_type': splitType,
          'category_id': categoryId,
          'created_by': userId,
        })
        .select('id')
        .single();

    final expenseId = expenseRow['id'] as String;

    // Insert all split rows atomically in one request.
    await supabase.from('expense_splits').insert(
      splits
          .map((s) => {
                'expense_id': expenseId,
                'member_id': s.memberId,
                'share_amount': s.shareAmount.toString(),
                if (s.sharePercent != null)
                  'share_percent': s.sharePercent.toString(),
              })
          .toList(),
    );
  }
}
