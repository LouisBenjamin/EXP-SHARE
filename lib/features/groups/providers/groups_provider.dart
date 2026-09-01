import 'package:tally/features/groups/data/groups_repository.dart';
import 'package:tally/models/group.dart';
import 'package:tally/models/group_member.dart';
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

// Roster for a group (real users + guests).
// Invalidate with ref.invalidate(membersProvider(groupId)) after adding a member.
final membersProvider = FutureProvider.family<List<GroupMember>, String>(
  (ref, groupId) => GroupsRepository().fetchMembers(groupId: groupId),
);
