import 'activity.dart';

/// Compact representation of the runner's recent training.
///
/// The AI coach receives this summary instead of the complete
/// activity database and GPS routes.
class RunnerFitnessSummary {
  const RunnerFitnessSummary({
    required this.activityCount,
    required this.totalDistanceKm,
    required this.averageDistanceKm,
    required this.longestRunKm,
    required this.recentWeeklyMileageKm,
    required this.recentActivities,
    this.averagePaceMinPerKm,
  });

  final int activityCount;
  final double totalDistanceKm;
  final double averageDistanceKm;
  final double longestRunKm;
  final double recentWeeklyMileageKm;
  final double? averagePaceMinPerKm;
  final List<RecentActivitySummary> recentActivities;

  factory RunnerFitnessSummary.fromActivities(
    List<Activity> activities,
  ) {
    if (activities.isEmpty) {
      return const RunnerFitnessSummary(
        activityCount: 0,
        totalDistanceKm: 0,
        averageDistanceKm: 0,
        longestRunKm: 0,
        recentWeeklyMileageKm: 0,
        averagePaceMinPerKm: null,
        recentActivities: [],
      );
    }

    final completed = activities
        .where(
          (activity) =>
              activity.status == ActivityStatus.finished &&
              activity.distanceMeters > 0,
        )
        .toList();

    if (completed.isEmpty) {
      return const RunnerFitnessSummary(
        activityCount: 0,
        totalDistanceKm: 0,
        averageDistanceKm: 0,
        longestRunKm: 0,
        recentWeeklyMileageKm: 0,
        averagePaceMinPerKm: null,
        recentActivities: [],
      );
    }

    final totalDistanceKm = completed.fold<double>(
      0,
      (sum, activity) => sum + activity.distanceKm,
    );

    final averageDistanceKm =
        totalDistanceKm / completed.length;

    final longestRunKm = completed.fold<double>(
      0,
      (longest, activity) =>
          activity.distanceKm > longest
              ? activity.distanceKm
              : longest,
    );

    final paceActivities = completed
        .where(
          (activity) => activity.paceMinPerKm != null,
        )
        .toList();

    double? averagePaceMinPerKm;

    if (paceActivities.isNotEmpty) {
      final totalPace = paceActivities.fold<double>(
        0,
        (sum, activity) =>
            sum + activity.paceMinPerKm!,
      );

      averagePaceMinPerKm =
          totalPace / paceActivities.length;
    }

    final recentActivities = completed
        .take(10)
        .map(
          (activity) => RecentActivitySummary(
            date: activity.startedAt,
            distanceKm: activity.distanceKm,
            durationMinutes:
                activity.durationSeconds / 60,
            paceMinPerKm: activity.paceMinPerKm,
          ),
        )
        .toList();

    final recentWeeklyMileageKm =
        _calculateRecentWeeklyMileage(completed);

    return RunnerFitnessSummary(
      activityCount: completed.length,
      totalDistanceKm: totalDistanceKm,
      averageDistanceKm: averageDistanceKm,
      longestRunKm: longestRunKm,
      recentWeeklyMileageKm: recentWeeklyMileageKm,
      averagePaceMinPerKm: averagePaceMinPerKm,
      recentActivities: recentActivities,
    );
  }

  static double _calculateRecentWeeklyMileage(
    List<Activity> activities,
  ) {
    final now = DateTime.now();
    final cutoff =
        now.subtract(const Duration(days: 28));

    final recent = activities.where(
      (activity) =>
          !activity.startedAt.isBefore(cutoff),
    );

    final distance = recent.fold<double>(
      0,
      (sum, activity) =>
          sum + activity.distanceKm,
    );

    return distance / 4;
  }
}

class RecentActivitySummary {
  const RecentActivitySummary({
    required this.date,
    required this.distanceKm,
    required this.durationMinutes,
    this.paceMinPerKm,
  });

  final DateTime date;
  final double distanceKm;
  final double durationMinutes;
  final double? paceMinPerKm;
}