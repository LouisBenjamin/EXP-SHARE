import 'package:exp_share/features/groups/data/groups_repository.dart';
import 'package:exp_share/models/group.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// All groups for the current user.
// Invalidate with ref.invalidate(groupsProvider) after create/update.
final groupsProvider = FutureProvider<List<Group>>((ref) {
  return GroupsRepository().fetchGroups();
});

// Single group by ID — used by GroupDetailScreen.
final groupProvider = FutureProvider.family<Group, String>((ref, groupId) {
  return GroupsRepository().fetchGroup(id: groupId);
});
