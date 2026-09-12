import 'package:flutter/foundation.dart';
 
/// Immutable snapshot of a user's profile.
///
/// Immutability + a proper `==`/`hashCode` matter here: Riverpod decides
/// whether to rebuild watchers by comparing old vs new state with `==`.
/// If we used a mutable class (or forgot to override `==`), every fetch
/// would count as "new data" even when nothing actually changed, causing
/// pointless rebuilds of the whole screen.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.bio,
    required this.stats,
    required this.achievements,
    this.coverPhotoUrl,
    this.isFollowing = false,
  });
 
  final String id;
  final String name;
  final String username;
  final String avatarUrl;
  final String? coverPhotoUrl;
  final String bio;
  final ProfileStats stats;
  final List<Achievement> achievements;
  final bool isFollowing;
 
  UserProfile copyWith({
    String? name,
    String? username,
    String? avatarUrl,
    String? coverPhotoUrl,
    String? bio,
    ProfileStats? stats,
    List<Achievement>? achievements,
    bool? isFollowing,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      bio: bio ?? this.bio,
      stats: stats ?? this.stats,
      achievements: achievements ?? this.achievements,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
 
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          id == other.id &&
          name == other.name &&
          username == other.username &&
          avatarUrl == other.avatarUrl &&
          coverPhotoUrl == other.coverPhotoUrl &&
          bio == other.bio &&
          stats == other.stats &&
          isFollowing == other.isFollowing &&
          listEquals(achievements, other.achievements));
 
  @override
  int get hashCode => Object.hash(
        id,
        name,
        username,
        avatarUrl,
        coverPhotoUrl,
        bio,
        stats,
        isFollowing,
        Object.hashAll(achievements),
      );
}
 
@immutable
class ProfileStats {
  const ProfileStats({
    required this.totalDistanceKm,
    required this.totalActivities,
    required this.totalMovingTime,
    required this.totalElevationGainM,
    required this.followers,
    required this.following,
  });
 
  final double totalDistanceKm;
  final int totalActivities;
  final Duration totalMovingTime;
  final double totalElevationGainM;
  final int followers;
  final int following;
 
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileStats &&
          totalDistanceKm == other.totalDistanceKm &&
          totalActivities == other.totalActivities &&
          totalMovingTime == other.totalMovingTime &&
          totalElevationGainM == other.totalElevationGainM &&
          followers == other.followers &&
          following == other.following);
 
  @override
  int get hashCode => Object.hash(
        totalDistanceKm,
        totalActivities,
        totalMovingTime,
        totalElevationGainM,
        followers,
        following,
      );
}
 
@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.iconAsset,
    required this.unlockedAt,
  });
 
  final String id;
  final String title;
  final String iconAsset;
  final DateTime unlockedAt;
 
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Achievement && id == other.id);
 
  @override
  int get hashCode => id.hashCode;
}
 