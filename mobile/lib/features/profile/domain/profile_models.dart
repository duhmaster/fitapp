class Profile {
  Profile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });
  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Profile copyWith({String? displayName, String? avatarUrl}) {
    return Profile(
      id: id,
      userId: userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
