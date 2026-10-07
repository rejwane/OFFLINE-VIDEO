class CreatorProfile {
  const CreatorProfile({
    required this.id,
    required this.name,
    required this.bio,
    required this.videoIds,
    this.avatarPath,
  });

  final String id;
  final String name;
  final String bio;
  final String? avatarPath;
  final List<String> videoIds;

  CreatorProfile copyWith({
    String? name,
    String? bio,
    String? avatarPath,
    bool clearAvatar = false,
    List<String>? videoIds,
  }) {
    return CreatorProfile(
      id: id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      videoIds: videoIds ?? this.videoIds,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'bio': bio,
        'avatarPath': avatarPath,
        'videoIds': videoIds,
      };

  factory CreatorProfile.fromJson(Map<String, dynamic> json) {
    return CreatorProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Creator',
      bio: json['bio'] as String? ?? '',
      avatarPath: json['avatarPath'] as String?,
      videoIds: (json['videoIds'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}
