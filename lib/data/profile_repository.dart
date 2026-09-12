import '../models/user_profile.dart';
 
/// Contract for fetching/updating profile data.
///
/// Nothing above this layer (providers, widgets) ever imports Firebase,
/// Dio, or any backend package directly. They only depend on this
/// interface. That means when you're ready to connect Firestore or your
/// own API, you write `FirebaseProfileRepository implements ProfileRepository`
/// and change one line in the provider file — zero changes to the screen.
abstract class ProfileRepository {
  Future<UserProfile> fetchProfile(String userId);
  Future<void> setFollowing(String userId, bool isFollowing);
}
 
/// Temporary in-memory implementation so the screen is fully functional
/// and demoable before the real backend exists.
class MockProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> fetchProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 700));
    return UserProfile(
      id: userId,
      name: 'Harshwardhan',
      username: '@harsh.runs',
      avatarUrl: 'https://i.pravatar.cc/300?img=12',
      coverPhotoUrl: 'https://picsum.photos/id/1015/900/500',
      bio: 'Building Stride 🏃 | CS @ Amity | Chasing a sub-20 5K',
      stats: const ProfileStats(
        totalDistanceKm: 482.6,
        totalActivities: 63,
        totalMovingTime: Duration(hours: 51, minutes: 12),
        totalElevationGainM: 3120,
        followers: 214,
        following: 98,
      ),
      achievements: [
        Achievement(
          id: 'a1',
          title: 'First 10K',
          iconAsset: 'assets/badges/10k.png',
          unlockedAt: DateTime(2026, 3, 2),
        ),
        Achievement(
          id: 'a2',
          title: '30-Day Streak',
          iconAsset: 'assets/badges/streak30.png',
          unlockedAt: DateTime(2026, 6, 18),
        ),
        Achievement(
          id: 'a3',
          title: 'Sub-25 5K',
          iconAsset: 'assets/badges/sub25.png',
          unlockedAt: DateTime(2026, 7, 30),
        ),
      ],
      isFollowing: false,
    );
  }
 
  @override
  Future<void> setFollowing(String userId, bool isFollowing) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Real implementation: POST /users/{id}/follow, or a Firestore write.
  }
}
 