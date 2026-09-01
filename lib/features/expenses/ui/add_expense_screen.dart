import 'package:decimal/decimal.dart';
import 'package:exp_share/core/money.dart';
import 'package:exp_share/core/supabase_client.dart';
import 'package:exp_share/features/expenses/data/expenses_repository.dart';
import 'package:exp_share/features/expenses/providers/categories_provider.dart';
import 'package:exp_share/features/groups/providers/groups_provider.dart';
import 'package:exp_share/models/category.dart';
import 'package:exp_share/models/group_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

typedef Split = ({String memberId, Decimal shareAmount, Decimal? sharePercent});

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, required this.groupId});
  final String groupId;

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

  Decimal get _amount => Decimal.tryParse(_amountController.text.trim()) ?? Decimal.zero;

  TextEditingController _exact(String id) =>
      _exactCtl.putIfAbsent(id, () => TextEditingController());
  TextEditingController _percent(String id) =>
      _percentCtl.putIfAbsent(id, () => TextEditingController());

  // Compute splits + a validity/status for the current inputs.
  ({bool valid, String status, List<Split> splits}) _compute(
      List<GroupMember> members) {
    final amount = _amount;
    final selected = members.where((m) => _selected.contains(m.id)).toList();
    if (selected.isEmpty) {
      return (valid: false, status: 'Select at least one participant', splits: []);
    }
    if (amount <= Decimal.zero) {
      return (valid: false, status: 'Enter an amount', splits: []);
    }

    switch (_splitType) {
      case 'exact':
        var sum = Decimal.zero;
        final splits = <Split>[];
        for (final m in selected) {
          final v = Decimal.tryParse(_exact(m.id).text.trim()) ?? Decimal.zero;
          sum += v;
          splits.add((memberId: m.id, shareAmount: v, sharePercent: null));
        }
        final ok = sum == amount;
        return (
          valid: ok,
          status: ok
              ? 'Splits add up ✓'
              : 'Assigned ${formatCurrency(sum)} of ${formatCurrency(amount)}',
          splits: splits,
        );
      case 'percent':
        var pctSum = Decimal.zero;
        final entered = <(GroupMember, Decimal)>[];
        for (final m in selected) {
          final p = Decimal.tryParse(_percent(m.id).text.trim()) ?? Decimal.zero;
          pctSum += p;
          entered.add((m, p));
        }
        final ok = pctSum == Decimal.fromInt(100);
        final splits = <Split>[];
        var assigned = Decimal.zero;
        for (var i = 0; i < entered.length; i++) {
          final (m, p) = entered[i];
          // Last participant absorbs the rounding remainder for an exact sum.
          final share =
              i == entered.length - 1 ? amount - assigned : percentShare(amount, p);
          if (i != entered.length - 1) assigned += share;
          splits.add((memberId: m.id, shareAmount: share, sharePercent: p));
        }
        return (
          valid: ok,
          status: ok ? 'Percentages add up ✓' : 'Total $pctSum% (need 100%)',
          splits: splits,
        );
      default: // equal
        final shares = splitEqually(amount, selected.length);
        final splits = [
          for (var i = 0; i < selected.length; i++)
            (memberId: selected[i].id, shareAmount: shares[i], sharePercent: null),
        ];
        return (valid: true, status: 'Split equally', splits: splits);
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
      await ExpensesRepository().createExpense(
        groupId: widget.groupId,
        payerMemberId: _payerMemberId!,
        amount: _amount,
        description: _descriptionController.text.trim(),
        splitType: _splitType,
        categoryId: _categoryId,
        splits: result.splits,
      );
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
    final categoriesAsync = ref.watch(categoriesProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Add expense')),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) {
          if (!_inited && members.isNotEmpty) {
            _selected.addAll(members.map((m) => m.id));
            final myUid = supabase.auth.currentUser?.id;
            _payerMemberId = members
                    .where((m) => m.userId == myUid)
                    .map((m) => m.id)
                    .firstOrNull ??
                members.first.id;
            _inited = true;
          }

          final compute = _compute(members);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
              children: [
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'equal', label: Text('Equally')),
                    ButtonSegment(value: 'exact', label: Text('Exact')),
                    ButtonSegment(value: 'percent', label: Text('%')),
                  ],
                  selected: {_splitType},
                  onSelectionChanged: (s) => setState(() => _splitType = s.first),
                ),
                const SizedBox(height: 8),
                ...members.map((m) => _ParticipantRow(
                      member: m,
                      included: _selected.contains(m.id),
                      splitType: _splitType,
                      equalShare: _splitType == 'equal' &&
                              _selected.contains(m.id) &&
                              _selected.isNotEmpty
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
                  onPressed: _submitting || !compute.valid
                      ? null
                      : () => _submit(members),
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
          );
        },
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

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.member,
    required this.included,
    required this.splitType,
    required this.equalShare,
    required this.exactController,
    required this.percentController,
    required this.onToggle,
    required this.onChanged,
  });

  final GroupMember member;
  final bool included;
  final String splitType;
  final Decimal? equalShare;
  final TextEditingController exactController;
  final TextEditingController percentController;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    Widget? trailing;
    if (included) {
      switch (splitType) {
        case 'exact':
          trailing = _MiniField(
            controller: exactController,
            prefix: r'$',
            onChanged: onChanged,
          );
        case 'percent':
          trailing = _MiniField(
            controller: percentController,
            suffix: '%',
            onChanged: onChanged,
          );
        default:
          trailing = Text(
            equalShare != null ? formatCurrency(equalShare!) : '',
            style: Theme.of(context).textTheme.bodyMedium,
          );
      }
    }

    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: included,
      onChanged: (v) => onToggle(v ?? false),
      title: Text(member.displayName),
      secondary: trailing,
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.controller,
    required this.onChanged,
    this.prefix,
    this.suffix,
  });
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.end,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          isDense: true,
          prefixText: prefix,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
