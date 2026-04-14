/// Mirrors the backend UserDto shape from @fitcore/shared.
class UserDto {
  const UserDto({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.dateOfBirth,
    this.gender,
    this.heightCm,
    required this.hasProfile,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? dateOfBirth;
  final String? gender;
  final double? heightCm;
  final bool hasProfile;
  final String createdAt;

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        dateOfBirth: json['dateOfBirth'] as String?,
        gender: json['gender'] as String?,
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        hasProfile: (json['hasProfile'] as bool?) ?? false,
        createdAt: json['createdAt'] as String,
      );

  UserDto copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? dateOfBirth,
    String? gender,
    double? heightCm,
    bool? hasProfile,
    String? createdAt,
  }) =>
      UserDto(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        gender: gender ?? this.gender,
        heightCm: heightCm ?? this.heightCm,
        hasProfile: hasProfile ?? this.hasProfile,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// Holds the authenticated session. null = unauthenticated.
class AuthState {
  const AuthState({required this.user, required this.accessToken});

  final UserDto user;

  /// Access token (15-min JWT). Lives only in Riverpod memory.
  final String accessToken;
}
