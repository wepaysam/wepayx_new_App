class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.createdAt,
  });

  final int id;
  final String email;
  final String? name;
  final String? createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
