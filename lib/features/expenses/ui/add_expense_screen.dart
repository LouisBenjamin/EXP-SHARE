import 'package:decimal/decimal.dart';
import 'package:exp_share/core/supabase_client.dart';
import 'package:exp_share/core/widgets/page_body.dart';
import 'package:exp_share/features/expenses/data/expenses_repository.dart';
import 'package:exp_share/features/expenses/providers/categories_provider.dart';
import 'package:exp_share/features/expenses/providers/expense_splits_provider.dart';
import 'package:exp_share/features/expenses/providers/expenses_provider.dart';
import 'package:exp_share/features/expenses/split_logic.dart';
import 'package:exp_share/features/expenses/ui/split_editor.dart';
import 'package:exp_share/features/groups/providers/groups_provider.dart';
import 'package:exp_share/models/category.dart';
import 'package:exp_share/models/expense.dart';
import 'package:exp_share/models/expense_split.dart';
import 'package:exp_share/models/group_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Doubles as the add and edit form. Pass [expenseId] to edit an existing
// expense; leave it null to create a new one.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, required this.groupId, this.expenseId});
  final String groupId;
  final String? expenseId;

  bool get isEditing => expenseId != null;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final Map<String, TextEditingController> _exactCtl = {};
  final Map<String, TextEditingController> _percentCtl = {};

  String _splitType = 'equal';
  final Set<String> _selected = {};
  String? _payerMemberId;
  String? _categoryId;
  bool _inited = false;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    for (final c in _exactCtl.values) {
      c.dispose();
    }
    for (final c in _percentCtl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Decimal get _amount =>
      Decimal.tryParse(_amountController.text.trim()) ?? Decimal.zero;

  TextEditingController _exact(String id) =>
      _exactCtl.putIfAbsent(id, () => TextEditingController());
  TextEditingController _percent(String id) =>
      _percentCtl.putIfAbsent(id, () => TextEditingController());

  SplitOutcome _compute(List<GroupMember> members) => computeSplits(
        splitType: _splitType,
        orderedMemberIds: members.map((m) => m.id).toList(),
        selected: _selected,
        amount: _amount,
        exact: {
          for (final id in _selected)
            id: Decimal.tryParse(_exact(id).text.trim()) ?? Decimal.zero,
        },
        percent: {
          for (final id in _selected)
            id: Decimal.tryParse(_percent(id).text.trim()) ?? Decimal.zero,
        },
      );

  // Seed defaults for a new expense: everyone included, current user pays.
  void _initNew(List<GroupMember> members) {
    _selected.addAll(members.map((m) => m.id));
    final myUid = supabase.auth.currentUser?.id;
    _payerMemberId =
        members.where((m) => m.userId == myUid).map((m) => m.id).firstOrNull ??
            members.first.id;
  }

  // Seed the form from an existing expense + its splits (edit mode).
  void _initExisting(Expense e, List<ExpenseSplit> splits) {
    _amountController.text = e.amount.toString();
    _descriptionController.text = e.description;
    _categoryId = e.categoryId;
    _payerMemberId = e.payerMemberId;
    _splitType = e.splitType;
    _selected
      ..clear()
      ..addAll(splits.map((s) => s.memberId));
    for (final s in splits) {
      _exact(s.memberId).text = s.shareAmount.toString();
      if (s.sharePercent != null) {
        _percent(s.memberId).text = s.sharePercent.toString();
      }
    }
  }

  Future<void> _submit(List<GroupMember> members) async {
    if (!_formKey.currentState!.validate()) return;
    if (_payerMemberId == null) return;
    final result = _compute(members);
    if (!result.valid) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.status)));
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ExpensesRepository();
      if (widget.isEditing) {
        await repo.updateExpense(
          expenseId: widget.expenseId!,
          payerMemberId: _payerMemberId!,
          amount: _amount,
          description: _descriptionController.text.trim(),
          splitType: _splitType,
          categoryId: _categoryId,
          splits: result.splits,
        );
      } else {
        await repo.createExpense(
          groupId: widget.groupId,
          payerMemberId: _payerMemberId!,
          amount: _amount,
          description: _descriptionController.text.trim(),
          splitType: _splitType,
          categoryId: _categoryId,
          splits: result.splits,
        );
      }
      if (mounted) context.pop();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit expense' : 'Add expense'),
      ),
      body: PageBody(
        child: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (members) {
            if (members.isEmpty) {
              return const Center(child: Text('No members in this group.'));
            }
            // New expense: seed defaults immediately. Editing: wait for the
            // expense + its splits to load, then seed from them.
            if (!widget.isEditing) {
              if (!_inited) {
                _initNew(members);
                _inited = true;
              }
              return _form(members);
            }

            final expensesAsync = ref.watch(expensesProvider(widget.groupId));
            final splitsAsync =
                ref.watch(expenseSplitsProvider(widget.expenseId!));
            return expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (expenses) {
                final existing = expenses
                    .where((e) => e.id == widget.expenseId)
                    .firstOrNull;
                if (existing == null) {
                  return const Center(child: Text('Expense not found.'));
                }
                return splitsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (splits) {
                    if (!_inited) {
                      _initExisting(existing, splits);
                      _inited = true;
                    }
                    return _form(members);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _form(List<GroupMember> members) {
    final categoriesAsync = ref.watch(categoriesProvider(widget.groupId));
    final compute = _compute(members);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        children: [
          TextFormField(
            controller: _amountController,
            autofocus: !widget.isEditing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: r'$',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final a = Decimal.tryParse((v ?? '').trim());
              if (a == null || a <= Decimal.zero) {
                return 'Enter a valid amount';
              }
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
          _CategoryDropdown(
            categoriesAsync: categoriesAsync,
            value: _categoryId,
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _payerMemberId,
            decoration: const InputDecoration(
              labelText: 'Paid by',
              border: OutlineInputBorder(),
            ),
            items: members
                .map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.displayName),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _payerMemberId = v),
          ),
          const SizedBox(height: 24),
          Text('Split', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SplitTypeSelector(
            value: _splitType,
            onChanged: (v) => setState(() => _splitType = v),
          ),
          const SizedBox(height: 8),
          ...members.map((m) => ParticipantSplitRow(
                member: m,
                included: _selected.contains(m.id),
                splitType: _splitType,
                equalShare: _splitType == 'equal' && _selected.contains(m.id)
                    ? compute.splits
                        .where((s) => s.memberId == m.id)
                        .map((s) => s.shareAmount)
                        .firstOrNull
                    : null,
                exactController: _exact(m.id),
                percentController: _percent(m.id),
                onToggle: (on) => setState(() {
                  if (on) {
                    _selected.add(m.id);
                  } else {
                    _selected.remove(m.id);
                  }
                }),
                onChanged: () => setState(() {}),
              )),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                compute.valid ? Icons.check_circle : Icons.info_outline,
                size: 18,
                color: compute.valid
                    ? Colors.green
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(compute.status)),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed:
                _submitting || !compute.valid ? null : () => _submit(members),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isEditing ? 'Save changes' : 'Save expense'),
          ),
        ],
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categoriesAsync,
    required this.value,
    required this.onChanged,
  });
  final AsyncValue<List<Category>> categoriesAsync;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final categories = categoriesAsync.valueOrNull ?? const <Category>[];
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Category (optional)',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('None')),
        ...categories.map((c) => DropdownMenuItem(
              value: c.id,
              child: Row(
                children: [
                  Icon(iconForCategory(c.icon), size: 18),
                  const SizedBox(width: 8),
                  Text(c.name),
                ],
              ),
            )),
      ],
      onChanged: onChanged,
    );
  }
}
