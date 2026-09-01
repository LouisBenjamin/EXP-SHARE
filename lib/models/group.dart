class Group {
  const Group({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.createdBy,
    required this.createdAt,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String joinCode;
  final String createdBy;
  final DateTime createdAt;
  final String? photoUrl;

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        joinCode: json['join_code'] as String,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        photoUrl: json['photo_url'] as String?,
      );
}
