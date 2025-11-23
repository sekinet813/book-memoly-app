import 'package:collection/collection.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.name,
    this.bio,
    this.avatarUrl,
    this.readingThemes = const [],
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final themes = map['reading_themes'];
    return UserProfile(
      userId: map['user_id'] as String,
      name: map['name'] as String? ?? '',
      bio: map['bio'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      readingThemes: themes == null
          ? const []
          : (themes as List<dynamic>)
              .whereType<String>()
              .where((theme) => theme.trim().isNotEmpty)
              .toList(),
    );
  }

  final String userId;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final List<String> readingThemes;

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'bio': bio,
      'avatar_url': avatarUrl,
      'reading_themes': readingThemes,
    };
  }

  UserProfile copyWith({
    String? userId,
    String? name,
    String? bio,
    String? avatarUrl,
    List<String>? readingThemes,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      readingThemes: readingThemes ?? this.readingThemes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.userId == userId &&
        other.name == name &&
        other.bio == bio &&
        other.avatarUrl == avatarUrl &&
        const ListEquality<String>().equals(other.readingThemes, readingThemes);
  }

  @override
  int get hashCode => Object.hash(
        userId,
        name,
        bio,
        avatarUrl,
        const ListEquality<String>().hash(readingThemes),
      );
}
