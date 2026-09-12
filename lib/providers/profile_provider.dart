import 'package:flutter_riverpod/flutter_riverpod.dart';
 
import '../data/profile_repository.dart';
import '../models/user_profile.dart';
 
/// The ONE line you change when the real backend is ready:
/// `MockProfileRepository()` -> `FirebaseProfileRepository()`.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return MockProfileRepository();
});
 
/// Keyed by userId ("family") so viewing your own profile and a friend's
/// profile are cached and refreshed independently instead of colliding
/// in one shared piece of state.
final profileProvider =
    AsyncNotifierProvider.family<ProfileNotifier, UserProfile, String>(
  ProfileNotifier.new,
);
 
class ProfileNotifier extends FamilyAsyncNotifier<UserProfile, String> {
  @override
  Future<UserProfile> build(String userId) {
    return ref.read(profileRepositoryProvider).fetchProfile(userId);
  }
 
  /// Flips the follow flag immediately (optimistic update) so tapping
  /// "Follow" feels instant, then confirms with the backend in the
  /// background. If the backend call fails, it silently rolls back —
  /// no spinner, no jank, just a correct end state either way.
  Future<void> toggleFollow() async {
    final current = state.valueOrNull;
    if (current == null) return;
 
    final optimistic = current.copyWith(isFollowing: !current.isFollowing);
    state = AsyncData(optimistic);
 
    try {
      await ref
          .read(profileRepositoryProvider)
          .setFollowing(current.id, optimistic.isFollowing);
    } catch (_) {
      state = AsyncData(current);
    }
  }
 
  /// Full refresh (pull-to-refresh, retry button). Goes through loading
  /// state explicitly rather than just re-fetching silently, so the UI
  /// can show a spinner if it wants to.
  Future<void> refresh() async {
    state = const AsyncLoading<UserProfile>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).fetchProfile(arg),
    );
  }
}
 
