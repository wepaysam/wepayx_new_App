class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.createdAt,
    this.emailVerified,
    this.emailVerifiedAt,
  });

  final int id;
  final String email;
  final String? name;
  final String? createdAt;

  /// Explicit backend flag when present. `null` means the API did not send it
  /// (legacy accounts) — the app then falls back to local verification state.
  final bool? emailVerified;
  final String? emailVerifiedAt;

  UserModel copyWith({
    int? id,
    String? email,
    String? name,
    String? createdAt,
    bool? emailVerified,
    String? emailVerifiedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      emailVerified: emailVerified ?? this.emailVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    bool? verified;
    if (json.containsKey('emailVerified')) {
      verified = json['emailVerified'] == true;
    } else if (json.containsKey('email_verified')) {
      verified = json['email_verified'] == true;
    }

    return UserModel(
      id: json['id'] as int? ?? int.tryParse('${json['id']}') ?? 0,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      createdAt: (json['created_at'] ?? json['createdAt']) as String?,
      emailVerified: verified,
      emailVerifiedAt:
          (json['emailVerifiedAt'] ?? json['email_verified_at'])?.toString(),
    );
  }
}
