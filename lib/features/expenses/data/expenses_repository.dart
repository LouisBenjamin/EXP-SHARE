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

  // Push 1: caller passes a single split (the payer, full amount).
  // Push 2 replaces this with the full multi-member split logic.
  Future<void> createExpense({
    required String groupId,
    required String payerMemberId,
    required double amount,
    required String description,
    String splitType = 'equal',
    required List<({String memberId, double shareAmount})> splits,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    // Insert expense, get back the generated ID.
    final expenseRow = await supabase
        .from('expenses')
        .insert({
          'group_id': groupId,
          'payer_member_id': payerMemberId,
          'amount': amount,
          'description': description,
          'split_type': splitType,
          'created_by': userId,
        })
        .select('id')
        .single();

    final expenseId = (expenseRow)['id'] as String;

    // Insert all split rows atomically in one request.
    await supabase.from('expense_splits').insert(
      splits
          .map((s) => {
                'expense_id': expenseId,
                'member_id': s.memberId,
                'share_amount': s.shareAmount,
              })
          .toList(),
    );
  }
}
