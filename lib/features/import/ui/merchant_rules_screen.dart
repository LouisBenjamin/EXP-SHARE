import 'package:tally/core/widgets/page_body.dart';
import 'package:tally/features/expenses/providers/categories_provider.dart';
import 'package:tally/features/import/data/merchant_rules_repository.dart';
import 'package:tally/features/import/providers/import_providers.dart';
import 'package:tally/models/category.dart';
import 'package:tally/models/merchant_rule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// The group's tagging presets. Shared rather than per-device so everyone on a
// shared card tags the same merchant the same way.
class MerchantRulesScreen extends ConsumerStatefulWidget {
  const MerchantRulesScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<MerchantRulesScreen> createState() =>
      _MerchantRulesScreenState();
}

class _MerchantRulesScreenState extends ConsumerState<MerchantRulesScreen> {
  Future<void> _edit({MerchantRule? existing}) async {
    final categories =
        ref.read(categoriesProvider(widget.groupId)).valueOrNull ??
            const <Category>[];

    final draft = await showDialog<RuleDraft>(
      context: context,
      builder: (_) => RuleDialog(categories: categories, existing: existing),
    );
    if (draft == null) return;

    try {
      final repo = MerchantRulesRepository();
      if (existing == null) {
        await repo.createRule(
          groupId: widget.groupId,
          pattern: draft.pattern,
          matchType: draft.matchType,
          action: draft.action,
          categoryId: draft.categoryId,
          priority: draft.priority,
        );
      } else {
        await repo.updateRule(
          id: existing.id,
          pattern: draft.pattern,
          matchType: draft.matchType,
          action: draft.action,
          categoryId: draft.categoryId,
          priority: draft.priority,
        );
      }
      ref.invalidate(merchantRulesProvider(widget.groupId));
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _delete(MerchantRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('${rule.pattern} will no longer be tagged automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await MerchantRulesRepository().deleteRule(id: rule.id);
      ref.invalidate(merchantRulesProvider(widget.groupId));
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(merchantRulesProvider(widget.groupId));
    final categories =
        ref.watch(categoriesProvider(widget.groupId)).valueOrNull ??
            const <Category>[];
    final nameOf = {for (final c in categories) c.id: c};

    return Scaffold(
      appBar: AppBar(title: const Text('Merchant rules')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New rule'),
      ),
      body: PageBody(
        child: rulesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (rules) {
            if (rules.isEmpty) return const _EmptyRules();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final rule = rules[i];
                final category = nameOf[rule.categoryId];
                return Card(
                  clipBehavior: Clip.hardEdge,
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        rule.isSkip
                            ? Icons.block
                            : iconForCategory(category?.icon ?? 'label'),
                      ),
                    ),
                    title: Text(rule.pattern),
                    subtitle: Text(
                      rule.isSkip
                          ? '${rule.matchType} · never shared'
                          : '${rule.matchType} · ${category?.name ?? 'no category'}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(rule),
                    ),
                    onTap: () => _edit(existing: rule),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class RuleDraft {
  const RuleDraft({
    required this.pattern,
    required this.matchType,
    required this.action,
    required this.priority,
    this.categoryId,
  });

  final String pattern;
  final String matchType;
  final String action;
  final int priority;
  final String? categoryId;
}

class RuleDialog extends StatefulWidget {
  const RuleDialog({super.key, required this.categories, this.existing});

  final List<Category> categories;
  final MerchantRule? existing;

  @override
  State<RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<RuleDialog> {
  late final _pattern =
      TextEditingController(text: widget.existing?.pattern ?? '');
  late String _matchType = widget.existing?.matchType ?? 'contains';
  late String? _categoryId = widget.existing?.categoryId;
  late bool _share = !(widget.existing?.isSkip ?? false);

  @override
  void dispose() {
    _pattern.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New rule' : 'Edit rule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pattern,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Merchant pattern',
                helperText: 'e.g. COSTCO WHOLESALE',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'contains', label: Text('Contains')),
                ButtonSegment(value: 'prefix', label: Text('Starts')),
                ButtonSegment(value: 'exact', label: Text('Exact')),
              ],
              selected: {_matchType},
              onSelectionChanged: (s) => setState(() => _matchType = s.first),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in widget.categories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: _share ? (v) => setState(() => _categoryId = v) : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _share,
              onChanged: (v) => setState(() => _share = v),
              title: const Text('Share with the group'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final pattern = _pattern.text.trim();
            if (pattern.isEmpty) return;
            Navigator.pop(
              context,
              RuleDraft(
                pattern: pattern,
                matchType: _matchType,
                action: _share ? 'share' : 'skip',
                priority: widget.existing?.priority ?? 100,
                categoryId: _share ? _categoryId : null,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EmptyRules extends StatelessWidget {
  const _EmptyRules();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rule, size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('No rules yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Rules tag imported transactions automatically, for everyone in '
              'the group. Add one here, or from a transaction while reviewing '
              'a statement.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
