import 'package:exp_share/features/expenses/data/expenses_repository.dart';
import 'package:exp_share/features/groups/data/groups_repository.dart';
import 'package:exp_share/models/group_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// Push 1 scope: payer = current user, split = full amount to payer.
// Push 2 will add member selection and real split type UI.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, required this.groupId});
  final String groupId;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  GroupMember? _currentMember;
  bool _loadingMember = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentMember();
  }

  Future<void> _loadCurrentMember() async {
    final member = await GroupsRepository().fetchCurrentUserMember(
      groupId: widget.groupId,
    );
    if (mounted) setState(() { _currentMember = member; _loadingMember = false; });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentMember == null) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    setState(() => _submitting = true);
    try {
      await ExpensesRepository().createExpense(
        groupId: widget.groupId,
        payerMemberId: _currentMember!.id,
        amount: amount,
        description: _descriptionController.text.trim(),
        splitType: 'equal',
        // Push 1: sole participant is the payer — full amount as their share.
        // This placeholder is replaced in Push 2 with multi-member splits.
        splits: [(memberId: _currentMember!.id, shareAmount: amount)],
      );
      if (mounted) context.pop();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMember) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final amount = double.tryParse(v ?? '');
                if (amount == null || amount <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Dinner, Groceries…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_currentMember != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: const Text('Paid by'),
                trailing: Text(
                  _currentMember!.displayName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}
