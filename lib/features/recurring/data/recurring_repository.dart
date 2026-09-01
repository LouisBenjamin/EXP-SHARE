import 'package:decimal/decimal.dart';
import 'package:exp_share/core/supabase_client.dart';
import 'package:exp_share/features/expenses/split_logic.dart';
import 'package:exp_share/models/recurring_expense.dart';

class RecurringRepository {
  Future<List<RecurringExpense>> fetchRecurring({required String groupId}) async {
    final data = await supabase
        .from('recurring_expenses')
        .select()
        .eq('group_id', groupId)
        .order('next_occurrence');
    return (data as List)
        .map((e) => RecurringExpense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createRecurring({
    required String groupId,
    required String payerMemberId,
    required Decimal amount,
    required String description,
    required String splitType,
    String? categoryId,
    required String frequency,
    required int intervalCount,
    required DateTime nextOccurrence,
    required List<Split> splits,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final row = await supabase
        .from('recurring_expenses')
        .insert({
          'group_id': groupId,
          'payer_member_id': payerMemberId,
          'amount': amount.toString(),
          'description': description,
          'split_type': splitType,
          'category_id': categoryId,
          'frequency': frequency,
          'interval_count': intervalCount,
          'next_occurrence': _isoDate(nextOccurrence),
          'created_by': userId,
        })
        .select('id')
        .single();

    final recurringId = row['id'] as String;

    await supabase.from('recurring_expense_splits').insert(
      splits
          .map((s) => {
                'recurring_id': recurringId,
                'member_id': s.memberId,
                'share_amount': s.shareAmount.toString(),
                if (s.sharePercent != null)
                  'share_percent': s.sharePercent.toString(),
              })
          .toList(),
    );
  }

  Future<void> setActive({required String id, required bool active}) async {
    await supabase
        .from('recurring_expenses')
        .update({'active': active}).eq('id', id);
  }

  Future<void> deleteRecurring({required String id}) async {
    await supabase.from('recurring_expenses').delete().eq('id', id);
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
