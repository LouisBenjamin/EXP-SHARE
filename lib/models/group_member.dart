class GroupMember {
  const GroupMember({
    required this.id,
    required this.groupId,
    this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  final String id;
  final String groupId;
  final String? userId; // null = guest (Push 2+)
  final String displayName;
  final String role;
  final DateTime joinedAt;

  bool get isGuest => userId == null;

  // When querying with select('*, profiles(display_name)'):
  // - real users: display_name comes from the joined profiles row
  // - guests:     display_name is stored directly on group_members
  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final uid = json['user_id'] as String?;
    final name = uid != null
        ? (json['profiles']?['display_name'] as String? ?? 'User')
        : (json['display_name'] as String? ?? 'Guest');
    return GroupMember(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: uid,
      displayName: name,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
