import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';

/// The one line you change when a real backend exists —
/// `InMemoryActivityRepository()` -> `FirestoreActivityRepository()` or
/// similar. Nothing else in the app touches this.
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return InMemoryActivityRepository();
});

/// Holds the list of saved past activities for the history screen.
final activityHistoryProvider =
    AsyncNotifierProvider<ActivityHistoryNotifier, List<Activity>>(
  ActivityHistoryNotifier.new,
);

class ActivityHistoryNotifier extends AsyncNotifier<List<Activity>> {
  @override
  Future<List<Activity>> build() {
    return ref.read(activityRepositoryProvider).fetchHistory();
  }

  /// Saves a freshly finished run and updates the in-memory list
  /// immediately, instead of re-fetching from the repository — so the
  /// history screen shows the new run the instant it's saved, with no
  /// extra round trip.
  Future<void> addCompleted(Activity activity) async {
    await ref.read(activityRepositoryProvider).save(activity);
    final current = state.valueOrNull ?? const <Activity>[];
    state = AsyncData([activity, ...current]);
  }
}