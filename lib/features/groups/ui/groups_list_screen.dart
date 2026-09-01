import 'package:exp_share/core/widgets/page_body.dart';
import 'package:exp_share/features/groups/data/groups_repository.dart';
import 'package:exp_share/features/groups/providers/groups_provider.dart';
import 'package:exp_share/features/groups/ui/create_group_dialog.dart';
import 'package:exp_share/models/group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Join by code',
            icon: const Icon(Icons.login),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const JoinGroupDialog(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => CreateGroupDialog(
            onCreated: () => ref.invalidate(groupsProvider),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New group'),
      ),
      body: PageBody(
        child: groupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (groups) => groups.isEmpty
              ? const _EmptyState()
              : _GroupsGrid(groups: groups),
        ),
      ),
    );
  }
}

/// One column on a phone, up to three on a wide window, so the cards fill the
/// space instead of stacking into a single skinny ribbon down the middle.
class _GroupsGrid extends StatelessWidget {
  const _GroupsGrid({required this.groups});
  final List<Group> groups;

  static const _padding = EdgeInsets.fromLTRB(16, 16, 16, 96);
  static const _spacing = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ~360px is about the narrowest a card still reads well at.
        final columns = (constraints.maxWidth / 360).floor().clamp(1, 3);

        // Phones take the original list untouched.
        if (columns == 1) {
          return ListView.separated(
            padding: _padding,
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _GroupCard(group: groups[i]),
          );
        }

        return GridView.builder(
          padding: _padding,
          itemCount: groups.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: _spacing,
            mainAxisSpacing: _spacing,
            // A fixed height beats an aspect ratio here: the card wraps a
            // ListTile, which does not want to grow with the column width.
            mainAxisExtent: 88,
          ),
          itemBuilder: (_, i) => _GroupCard(group: groups[i]),
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            group.name.substring(0, 1).toUpperCase(),
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(group.name, style: theme.textTheme.titleMedium),
        subtitle: Text(
          'Code: ${group.joinCode}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/groups/${group.id}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_add, size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No groups yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create one and invite your people.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class JoinGroupDialog extends ConsumerStatefulWidget {
  const JoinGroupDialog({super.key});

  @override
  ConsumerState<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends ConsumerState<JoinGroupDialog> {
  final _controller = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() => _joining = true);
    try {
      final group = await GroupsRepository().joinGroupByCode(code: code);
      ref.invalidate(groupsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        context.push('/groups/${group.id}');
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join a group'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        onSubmitted: (_) => _join(),
        decoration: const InputDecoration(
          labelText: 'Invite code',
          hintText: 'e.g. AB452A',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _joining ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _joining ? null : _join,
          child: _joining
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}
