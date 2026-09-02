import 'package:tally/core/icons.dart';
import 'package:tally/models/category.dart';
import 'package:flutter/material.dart';

class CategoryDraft {
  const CategoryDraft({required this.name, required this.icon});
  final String name;
  final String icon;
}

// Create/edit a group category: a name plus one icon picked from
// kCategoryIcons. Global (group_id == null) categories never reach this
// dialog — the Labels tab renders them read-only.
class CategoryDialog extends StatefulWidget {
  const CategoryDialog({super.key, this.existing});
  final Category? existing;

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _icon = widget.existing?.icon ?? kCategoryIcons.keys.first;
  final _search = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.text.trim().toLowerCase();
    final entries = kCategoryIcons.entries
        .where((e) => query.isEmpty || e.key.contains(query))
        .toList();
    final tint = categoryTint(_icon, theme.brightness);

    return AlertDialog(
      title: Text(widget.existing == null ? 'New category' : 'Edit category'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tint,
                    child: Icon(iconForCategory(_icon), color: onCategoryTint(tint)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Category name',
                        hintText: 'e.g. Coffee',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search icons',
                  prefixIcon: Icon(AppIcons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: entries.isEmpty
                    ? const Center(child: Text('No icons match'))
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (_, i) {
                          final slug = entries[i].key;
                          final selected = slug == _icon;
                          return InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => setState(() => _icon = slug),
                            child: CircleAvatar(
                              backgroundColor: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                entries[i].value,
                                color: selected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, CategoryDraft(name: name, icon: _icon));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
