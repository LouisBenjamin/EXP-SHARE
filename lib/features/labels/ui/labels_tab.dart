import 'package:tally/core/icons.dart';
import 'package:tally/features/expenses/data/categories_repository.dart';
import 'package:tally/features/expenses/providers/categories_provider.dart';
import 'package:tally/features/import/data/merchant_rules_repository.dart';
import 'package:tally/features/import/providers/import_providers.dart';
import 'package:tally/features/labels/ui/category_dialog.dart';
import 'package:tally/features/labels/ui/tag_dialog.dart';
import 'package:tally/models/category.dart';
import 'package:tally/models/merchant_rule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Categories (icon + name, one per expense) and tags (a keyword that
// auto-assigns a category on import and on the Add-expense form) live
// together here — a tag is meaningless without the category it points at.
class LabelsTab extends ConsumerWidget {
  const LabelsTab({super.key, required this.groupId});
  final String groupId;

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref, {
    Category? existing,
  }) async {
    final draft = await showDialog<CategoryDraft>(
      context: context,
      builder: (_) => CategoryDialog(existing: existing),
    );
    if (draft == null) return;

    try {
      final repo = CategoriesRepository();
      if (existing == null) {
        await repo.createCategory(
            groupId: groupId, name: draft.name, icon: draft.icon);
      } else {
        await repo.updateCategory(
            id: existing.id, name: draft.name, icon: draft.icon);
      }
      ref.invalidate(categoriesProvider(groupId));
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteCategory(
      BuildContext context, WidgetRef ref, Category category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          '${category.name} will be removed. Expenses using it become '
          'uncategorized.',
        ),
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
      await CategoriesRepository().deleteCategory(id: category.id);
      ref.invalidate(categoriesProvider(groupId));
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _editTag(
    BuildContext context,
    WidgetRef ref,
    List<Category> categories, {
    MerchantRule? existing,
  }) async {
    final draft = await showDialog<RuleDraft>(
      context: context,
      builder: (_) => TagDialog(categories: categories, existing: existing),
    );
    if (draft == null) return;

    try {
      final repo = MerchantRulesRepository();
      if (existing == null) {
        await repo.createRule(
          groupId: groupId,
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
      ref.invalidate(merchantRulesProvider(groupId));
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteTag(
      BuildContext context, WidgetRef ref, MerchantRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete tag?'),
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
      ref.invalidate(merchantRulesProvider(groupId));
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider(groupId));
    final rulesAsync = ref.watch(merchantRulesProvider(groupId));
    final categories = categoriesAsync.valueOrNull ?? const <Category>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _SectionHeader(
          title: 'Categories',
          buttonLabel: 'New category',
          onAdd: () => _editCategory(context, ref),
        ),
        const SizedBox(height: 8),
        categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (categories) => categories.isEmpty
              ? const _EmptySection(
                  icon: AppIcons.tag,
                  message: 'No categories yet. Add one to start tagging expenses.',
                )
              : Column(
                  children: [
                    for (final c in categories)
                      _CategoryTile(
                        category: c,
                        onTap: c.groupId == null
                            ? null
                            : () => _editCategory(context, ref, existing: c),
                        onDelete: c.groupId == null
                            ? null
                            : () => _deleteCategory(context, ref, c),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Tags',
          buttonLabel: 'New tag',
          onAdd: categories.isEmpty
              ? null
              : () => _editTag(context, ref, categories),
        ),
        const SizedBox(height: 4),
        Text(
          'A tag matches a keyword against a merchant or a typed description '
          "and fills in its category automatically — e.g. \"COSTCO\" → Groceries.",
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        rulesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (rules) {
            if (rules.isEmpty) {
              return const _EmptySection(
                icon: AppIcons.tag,
                message: 'No tags yet.',
              );
            }
            final categoryById = {for (final c in categories) c.id: c};
            return Column(
              children: [
                for (final rule in rules)
                  _TagTile(
                    rule: rule,
                    category: categoryById[rule.categoryId],
                    onTap: () => _editTag(context, ref, categories, existing: rule),
                    onDelete: () => _deleteTag(context, ref, rule),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.buttonLabel,
    required this.onAdd,
  });
  final String title;
  final String buttonLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(AppIcons.add, size: 18),
          label: Text(buttonLabel),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.onDelete,
  });
  final Category category;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = categoryTint(category.id, theme.brightness);
    return Card(
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: tint,
          child: Icon(iconForCategory(category.icon), color: onCategoryTint(tint)),
        ),
        title: Text(category.name),
        trailing: onDelete == null
            ? const _Chip(label: 'Default')
            : IconButton(
                tooltip: 'Delete',
                icon: const Icon(AppIcons.delete),
                onPressed: onDelete,
              ),
      ),
    );
  }
}

class _TagTile extends StatelessWidget {
  const _TagTile({
    required this.rule,
    required this.category,
    required this.onTap,
    required this.onDelete,
  });
  final MerchantRule rule;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = category == null
        ? theme.colorScheme.surfaceContainerHighest
        : categoryTint(category!.id, theme.brightness);
    return Card(
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: tint,
          child: Icon(
            rule.isSkip ? AppIcons.block : iconForCategory(category?.icon ?? 'tag'),
            color: category == null
                ? theme.colorScheme.onSurfaceVariant
                : onCategoryTint(tint),
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
          icon: const Icon(AppIcons.delete),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.outlineVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.outline.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
