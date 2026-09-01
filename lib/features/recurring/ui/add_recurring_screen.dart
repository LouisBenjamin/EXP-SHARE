import 'package:decimal/decimal.dart';
import 'package:exp_share/core/money.dart';
import 'package:exp_share/core/supabase_client.dart';
import 'package:exp_share/features/expenses/providers/categories_provider.dart';
import 'package:exp_share/features/groups/providers/groups_provider.dart';
import 'package:exp_share/features/recurring/data/recurring_repository.dart';
import 'package:exp_share/models/category.dart';
import 'package:exp_share/models/group_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Push 4 scope: recurring templates split equally among selected participants.
// The schema stores generic splits, so exact/percent can be added later.
class AddRecurringScreen extends ConsumerStatefulWidget {
  const AddRecurringScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _AddRecurringScreenState extends ConsumerState<AddRecurringScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now();
  final Set<String> _selected = {};
  String? _payerMemberId;
  String? _categoryId;
  bool _inited = false;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Decimal get _amount =>
      Decimal.tryParse(_amountController.text.trim()) ?? Decimal.zero;
  int get _interval => int.tryParse(_intervalController.text.trim()) ?? 1;

  Future<void> _submit(List<GroupMember> members) async {
    if (!_formKey.currentState!.validate()) return;
    final selected = members.where((m) => _selected.contains(m.id)).toList();
    if (selected.isEmpty || _payerMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a payer and at least one participant')),
      );
      return;
    }

    final shares = splitEqually(_amount, selected.length);
    final splits = [
      for (var i = 0; i < selected.length; i++)
        (memberId: selected[i].id, shareAmount: shares[i], sharePercent: null),
    ];

    setState(() => _submitting = true);
    try {
      await RecurringRepository().createRecurring(
        groupId: widget.groupId,
        payerMemberId: _payerMemberId!,
        amount: _amount,
        description: _descriptionController.text.trim(),
        splitType: 'equal',
        categoryId: _categoryId,
        frequency: _frequency,
        intervalCount: _interval < 1 ? 1 : _interval,
        nextOccurrence: _startDate,
        splits: splits,
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
    final categories =
        ref.watch(categoriesProvider(widget.groupId)).valueOrNull ??
            const <Category>[];

    return Scaffold(
      appBar: AppBar(title: const Text('New recurring expense')),
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
          final perHead = _selected.isEmpty
              ? null
              : splitEqually(_amount, _selected.length).first;

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
                    hintText: 'e.g. Rent, Netflix, Internet…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
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
                Text('Repeats', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'daily', label: Text('Daily')),
                    ButtonSegment(value: 'weekly', label: Text('Weekly')),
                    ButtonSegment(value: 'monthly', label: Text('Monthly')),
                  ],
                  selected: {_frequency},
                  onSelectionChanged: (s) => setState(() => _frequency = s.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Every'),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: _intervalController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_unitLabel()),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text('Starts on'),
                  trailing: Text(DateFormat('MMM d, yyyy').format(_startDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                ),
                const SizedBox(height: 16),
                Text('Split equally between',
                    style: Theme.of(context).textTheme.titleSmall),
                ...members.map((m) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selected.contains(m.id),
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _selected.add(m.id);
                        } else {
                          _selected.remove(m.id);
                        }
                      }),
                      title: Text(m.displayName),
                      secondary: _selected.contains(m.id) && perHead != null
                          ? Text(formatCurrency(perHead))
                          : null,
                    )),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : () => _submit(members),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save recurring expense'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _unitLabel() {
    final plural = _interval != 1;
    return switch (_frequency) {
      'daily' => plural ? 'days' : 'day',
      'weekly' => plural ? 'weeks' : 'week',
      _ => plural ? 'months' : 'month',
    };
  }
}
