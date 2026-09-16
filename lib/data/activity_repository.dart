import '../models/activity.dart';

abstract class ActivityRepository {
  Future<List<Activity>> fetchHistory();

  Future<void> save(Activity activity);
}

class InMemoryActivityRepository implements ActivityRepository {
  final List<Activity> _activities = [];

  @override
  Future<List<Activity>> fetchHistory() async {
    return List.unmodifiable(_activities);
  }

  @override
  Future<void> save(Activity activity) async {
    _activities.removeWhere(
      (existing) => existing.id == activity.id,
    );

    _activities.insert(0, activity);
  }
}