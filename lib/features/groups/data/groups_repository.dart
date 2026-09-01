import 'package:exp_share/core/supabase_client.dart';
import 'package:exp_share/models/group.dart';
import 'package:exp_share/models/group_member.dart';

class GroupsRepository {
  Future<List<Group>> fetchGroups() async {
    final data = await supabase
        .from('groups')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => Group.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Group> fetchGroup({required String id}) async {
    final data = await supabase
        .from('groups')
        .select()
        .eq('id', id)
        .single();
    return Group.fromJson(data as Map<String, dynamic>);
  }

  Future<Group> createGroup({required String name}) async {
    final userId = supabase.auth.currentUser!.id;

    final groupData = await supabase
        .from('groups')
        .insert({'name': name, 'created_by': userId})
        .select()
        .single();

    final group = Group.fromJson(groupData as Map<String, dynamic>);

    // Add the creator as the first member (RLS allows this for group owners).
    await supabase.from('group_members').insert({
      'group_id': group.id,
      'user_id': userId,
      'role': 'owner',
    });

    return group;
  }

  Future<List<GroupMember>> fetchMembers({required String groupId}) async {
    final data = await supabase
        .from('group_members')
        .select('*, profiles(display_name)')
        .eq('group_id', groupId)
        .order('joined_at');
    return (data as List)
        .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroupMember?> fetchCurrentUserMember({required String groupId}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await supabase
        .from('group_members')
        .select('*, profiles(display_name)')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    return data == null ? null : GroupMember.fromJson(data as Map<String, dynamic>);
  }
}
