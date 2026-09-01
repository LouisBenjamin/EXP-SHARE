class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    this.groupId,
  });

  final String id;
  final String name;
  final String icon; // Material icon name hint (from the DB seed)
  final String? groupId; // null = global default category

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String? ?? 'label',
        groupId: json['group_id'] as String?,
      );
}
