import 'package:tally/features/groups/data/groups_repository.dart';
import 'package:tally/features/groups/providers/groups_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Landing screen for an invite link (/join?code=XXXXXX). The auth redirect in
// the router guarantees the user is signed in by the time they reach here, so
// we can join straight away and drop them into the group.
class JoinByLinkScreen extends ConsumerStatefulWidget {
  const JoinByLinkScreen({super.key, required this.code});
  final String? code;

  @override
  ConsumerState<JoinByLinkScreen> createState() => _JoinByLinkScreenState();
}

class _JoinByLinkScreenState extends ConsumerState<JoinByLinkScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  Future<void> _join() async {
    final code = widget.code?.trim() ?? '';
    if (code.isEmpty) {
      setState(() => _error = 'This invite link is missing its code.');
      return;
    }
    try {
      final group = await GroupsRepository().joinGroupByCode(code: code);
      ref.invalidate(groupsProvider);
      if (mounted) context.go('/groups/${group.id}');
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Joining group…')),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link_off,
                        size: 56,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go('/groups'),
                      child: const Text('Go to my groups'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
