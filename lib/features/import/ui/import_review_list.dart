import 'package:tally/core/dates.dart';
import 'package:tally/core/icons.dart';
import 'package:tally/core/money.dart';
import 'package:tally/features/import/logic/import_plan.dart';
import 'package:tally/models/category.dart';
import 'package:flutter/material.dart';

// The reviewable transaction list. Deliberately a plain StatelessWidget over
// ReviewRow + callbacks: it holds no state and touches no provider, so it can
// be widget-tested on its own.
//
// A card-per-row rather than a DataTable — the app has no tables anywhere, a
// table has no mobile story, and horizontal scroll would fight the 1100px
// content column.
class ImportReviewList extends StatelessWidget {
  const ImportReviewList({
    super.key,
    required this.rows,
    required this.categories,
    required this.onToggle,
    required this.onTag,
    required this.onAlwaysTag,
  });

  final List<ReviewRow> rows;
  final List<Category> categories;
  final void Function(ReviewRow row, bool selected) onToggle;
  final void Function(ReviewRow row) onTag;
  final void Function(ReviewRow row) onAlwaysTag;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyRows();
    }

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TransactionCard(
              row: row,
              category: _categoryFor(row.categoryId),
              onToggle: (v) => onToggle(row, v),
              onTag: () => onTag(row),
              onAlwaysTag: () => onAlwaysTag(row),
            ),
          ),
      ],
    );
  }

  Category? _categoryFor(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.row,
    required this.category,
    required this.onToggle,
    required this.onTag,
    required this.onAlwaysTag,
  });

  final ReviewRow row;
  final Category? category;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTag;
  final VoidCallback onAlwaysTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocked = !row.canImport;

    return Card(
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
        controlAffinity: ListTileControlAffinity.leading,
        value: row.selected && !blocked,
        // A disabled checkbox is how "already imported" reads at a glance.
        onChanged: blocked ? null : (v) => onToggle(v ?? false),
        title: Text(
          row.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: blocked
              ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
              : null,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                formatDay(row.occurredOn),
                style: theme.textTheme.bodySmall,
              ),
              if (blocked)
                const _Chip(label: 'Already imported', icon: AppIcons.doneAll)
              else
                ActionChip(
                  avatar: Icon(
                    category == null
                        ? AppIcons.tag
                        : iconForCategory(category!.icon),
                    size: 16,
                  ),
                  label: Text(category?.name ?? 'Tag'),
                  onPressed: onTag,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        secondary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatCurrency(row.amount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: blocked ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
            if (!blocked)
              IconButton(
                tooltip: 'Always tag this merchant',
                icon: const Icon(AppIcons.bookmarkAdd),
                onPressed: onAlwaysTag,
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRows extends StatelessWidget {
  const _EmptyRows();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            AppIcons.filterOff,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text('No transactions in range', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Widen the date range to see more.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
