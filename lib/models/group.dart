class Group {
  const Group({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String joinCode;
  final String createdBy;
  final DateTime createdAt;

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        joinCode: json['join_code'] as String,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
