import 'package:flutter/foundation.dart';

enum WorkoutType { rest, easyRun, longRun, tempo, intervals, crossTrain, race }

@immutable
class PlannedWorkout {
  const PlannedWorkout({
    required this.id,
    required this.scheduledDate,
    required this.type,
    this.targetDistanceKm,
    this.targetPaceMinPerKm,
    this.description,
    this.completed = false,
  });

  final String id;
  final DateTime scheduledDate;
  final WorkoutType type;
  final double? targetDistanceKm;
  final double? targetPaceMinPerKm;
  final String? description;
  final bool completed;

  bool get isCompleted => completed;

  PlannedWorkout copyWith({
    DateTime? scheduledDate,
    WorkoutType? type,
    double? targetDistanceKm,
    double? targetPaceMinPerKm,
    String? description,
    bool? completed,
  }) {
    return PlannedWorkout(
      id: id,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      type: type ?? this.type,
      targetDistanceKm: targetDistanceKm ?? this.targetDistanceKm,
      targetPaceMinPerKm: targetPaceMinPerKm ?? this.targetPaceMinPerKm,
      description: description ?? this.description,
      completed: completed ?? this.completed,
    );
  }
}

@immutable
class TrainingWeek {
  const TrainingWeek({
    required this.weekNumber,
    required this.focus,
    required this.workouts,
  });

  final int weekNumber;
  final String focus;
  final List<PlannedWorkout> workouts;
}

@immutable
class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.name,
    required this.goalDistanceKm,
    required this.workouts,
    this.goal,
    this.raceDate,
    this.targetTimeSeconds,
    this.createdAt,
    this.currentWeeklyMileageKm,
    this.currentLongestRunKm,
    this.weeks = const [],
  });

  final String id;
  final String name;
  final double goalDistanceKm;
  final List<PlannedWorkout> workouts;

  final TrainingGoal? goal;
  final DateTime? raceDate;

  /// Optional race target duration stored as total seconds.
  ///
  /// Examples:
  /// 25:00 -> 1500 seconds
  /// 50:00 -> 3000 seconds
  /// 1:45:00 -> 6300 seconds
  /// 3:45:00 -> 13500 seconds
  final int? targetTimeSeconds;

  final DateTime? createdAt;
  final double? currentWeeklyMileageKm;
  final double? currentLongestRunKm;
  final List<TrainingWeek> weeks;

  double get progress {
    if (workouts.isEmpty) {
      return 0;
    }

    final completed = workouts.where((workout) => workout.completed).length;

    return completed / workouts.length;
  }

  TrainingPlan copyWith({
    String? name,
    double? goalDistanceKm,
    List<PlannedWorkout>? workouts,
    TrainingGoal? goal,
    DateTime? raceDate,
    int? targetTimeSeconds,
    DateTime? createdAt,
    double? currentWeeklyMileageKm,
    double? currentLongestRunKm,
    List<TrainingWeek>? weeks,
  }) {
    return TrainingPlan(
      id: id,
      name: name ?? this.name,
      goalDistanceKm: goalDistanceKm ?? this.goalDistanceKm,
      workouts: workouts ?? this.workouts,
      goal: goal ?? this.goal,
      raceDate: raceDate ?? this.raceDate,
      targetTimeSeconds: targetTimeSeconds ?? this.targetTimeSeconds,
      createdAt: createdAt ?? this.createdAt,
      currentWeeklyMileageKm:
          currentWeeklyMileageKm ?? this.currentWeeklyMileageKm,
      currentLongestRunKm: currentLongestRunKm ?? this.currentLongestRunKm,
      weeks: weeks ?? this.weeks,
    );
  }
}

enum TrainingGoal { fiveK, tenK, halfMarathon, marathon }
