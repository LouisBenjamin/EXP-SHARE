import 'package:tally/models/category.dart';
import 'package:tally/models/merchant_rule.dart';
import 'package:flutter/material.dart';

// A tag is stored as a merchant_rules row: matching a keyword against either
// a statement merchant name (import) or a typed description (manual expense)
// assigns a category automatically. See matchMerchantRule / matchTagCategory
// in features/import/logic/merchant_rules.dart.
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

class TagDialog extends StatefulWidget {
  const TagDialog({super.key, required this.categories, this.existing});

  final List<Category> categories;
  final MerchantRule? existing;

  @override
  State<TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<TagDialog> {
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
      title: Text(widget.existing == null ? 'New tag' : 'Edit tag'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _pattern,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Keyword',
                  helperText: 'e.g. COSTCO — matched against merchant names '
                      'and expense descriptions',
                  border: OutlineInputBorder(),
                ),
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
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _share,
                onChanged: (v) => setState(() => _share = v),
                title: const Text('Share with the group'),
                subtitle: const Text('Off = never offer this merchant during import'),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Advanced'),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'contains', label: Text('Contains')),
                      ButtonSegment(value: 'prefix', label: Text('Starts')),
                      ButtonSegment(value: 'exact', label: Text('Exact')),
                    ],
                    selected: {_matchType},
                    onSelectionChanged: (s) => setState(() => _matchType = s.first),
                  ),
                ],
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
