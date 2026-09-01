import 'package:tally/core/money.dart';
import 'package:tally/core/widgets/page_body.dart';
import 'package:tally/features/groups/data/groups_repository.dart';
import 'package:tally/features/groups/providers/groups_provider.dart';
import 'package:tally/features/groups/ui/create_group_dialog.dart';
import 'package:tally/models/group_summary.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(groupSummariesProvider);

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
            onCreated: () {
              ref.invalidate(groupsProvider);
              ref.invalidate(groupSummariesProvider);
            },
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New group'),
      ),
      body: PageBody(
        child: summariesAsync.when(
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

/// Square tiles, as many per row as fit — a photo/initial fills the tile with
/// the name and "who owes what" status line overlaid at the bottom.
class _GroupsGrid extends StatelessWidget {
  const _GroupsGrid({required this.groups});
  final List<GroupSummary> groups;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: groups.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) => _GroupCard(summary: groups[i]),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.summary});
  final GroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = summary.photoUrl;

    return Card(
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/groups/${summary.id}'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photoUrl != null)
              Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _InitialTile(name: summary.name),
              )
            else
              _InitialTile(name: summary.name),

            // Scrim so the name/status stay legible over any photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.5, 1.0],
                ),
              ),
            ),

            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _StatusLine(net: summary.myNet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialTile extends StatelessWidget {
  const _InitialTile({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.primaryContainer,
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
          style: theme.textTheme.displayMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// "You owe $X" / "You're owed $X" / "Settled up", colored to match.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.net});
  final Decimal net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String label;
    final Color color;
    if (net.compareTo(Decimal.zero) > 0) {
      label = "You're owed ${formatCurrency(net)}";
      color = Colors.greenAccent.shade400;
    } else if (net.compareTo(Decimal.zero) < 0) {
      label = 'You owe ${formatCurrency(-net)}';
      color = Colors.redAccent.shade100;
    } else {
      label = 'Settled up';
      color = Colors.white70;
    }
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
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
      ref.invalidate(groupSummariesProvider);
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
