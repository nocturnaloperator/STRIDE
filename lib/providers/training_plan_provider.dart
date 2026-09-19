import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/training_plan_repository.dart';
import '../models/runner_fitness_summary.dart';
import '../models/training_plan.dart';
import '../models/training_plan_request.dart';
import '../services/ai_training_plan_service.dart';
import 'activity_history_provider.dart';

final trainingPlanRepositoryProvider =
    Provider<TrainingPlanRepository>((ref) {
  return InMemoryTrainingPlanRepository();
});

final aiTrainingPlanServiceProvider =
    Provider<AITrainingPlanService>((ref) {
  return const MockAITrainingPlanService();
});

final trainingPlanProvider =
    AsyncNotifierProvider<TrainingPlanNotifier, TrainingPlan?>(
  TrainingPlanNotifier.new,
);

class TrainingPlanNotifier extends AsyncNotifier<TrainingPlan?> {
  @override
  Future<TrainingPlan?> build() {
    return ref
        .read(trainingPlanRepositoryProvider)
        .fetchActivePlan();
  }

  /// Generates a training plan from the user's goal and
  /// their recent Stride activity history.
  Future<void> generatePlan({
    required TrainingGoal goal,
    required DateTime raceDate,
    required int trainingDaysPerWeek,
    int? targetTimeSeconds,
  }) async {
    state = const AsyncLoading();

    try {
      // Get the runner's real completed activities.
      final activities =
          await ref.read(activityHistoryProvider.future);

      // Convert raw activities into a compact fitness summary.
      final fitnessSummary =
          RunnerFitnessSummary.fromActivities(activities);

      // Build the information that the coach needs.
      final request = TrainingPlanRequest(
        goal: goal,
        raceDate: raceDate,
        trainingDaysPerWeek: trainingDaysPerWeek,
        targetTimeSeconds: targetTimeSeconds,
        currentWeeklyMileageKm:
            fitnessSummary.recentWeeklyMileageKm,
        currentLongestRunKm:
            fitnessSummary.longestRunKm,
        fitnessSummary: fitnessSummary,
      );

      // Ask the configured coach service to generate the plan.
      final service =
          ref.read(aiTrainingPlanServiceProvider);

      final generatedPlan =
          await service.generatePlan(request);

      // Save the generated plan using the repository.
      await ref
          .read(trainingPlanRepositoryProvider)
          .savePlan(generatedPlan);

      state = AsyncData(generatedPlan);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> setPlan(TrainingPlan plan) async {
    await ref
        .read(trainingPlanRepositoryProvider)
        .savePlan(plan);

    state = AsyncData(plan);
  }

  Future<void> clearPlan() async {
    state = const AsyncData(null);
  }

  Future<void> markWorkoutCompleted(String workoutId) async {
    final plan = state.valueOrNull;

    if (plan == null) return;

    final updatedWeeks = plan.weeks.map((week) {
      final updatedWorkouts = week.workouts.map((workout) {
        if (workout.id != workoutId) {
          return workout;
        }

        return workout.copyWith(completed: true);
      }).toList();

      return TrainingWeek(
        weekNumber: week.weekNumber,
        focus: week.focus,
        workouts: updatedWorkouts,
      );
    }).toList();

    final updatedWorkouts =
        updatedWeeks.expand((week) => week.workouts).toList();

    final updatedPlan = TrainingPlan(
      id: plan.id,
      name: plan.name,
      goalDistanceKm: plan.goalDistanceKm,
      workouts: updatedWorkouts,
      goal: plan.goal,
      raceDate: plan.raceDate,
      targetTimeSeconds: plan.targetTimeSeconds,
      createdAt: plan.createdAt,
      currentWeeklyMileageKm:
          plan.currentWeeklyMileageKm,
      currentLongestRunKm:
          plan.currentLongestRunKm,
      weeks: updatedWeeks,
    );

    await ref
        .read(trainingPlanRepositoryProvider)
        .savePlan(updatedPlan);

    state = AsyncData(updatedPlan);
  }
}

final suggestedWorkoutProvider =
    Provider<SuggestedWorkout?>((ref) {
  final planAsync = ref.watch(trainingPlanProvider);
  final plan = planAsync.valueOrNull;

  if (plan == null) {
    return null;
  }

  final today = DateTime.now();
  final todayOnly = DateTime(
    today.year,
    today.month,
    today.day,
  );

  final upcoming = plan.workouts
      .where(
        (workout) =>
            !workout.completed &&
            !workout.scheduledDate.isBefore(todayOnly),
      )
      .toList()
    ..sort(
      (a, b) =>
          a.scheduledDate.compareTo(b.scheduledDate),
    );

  if (upcoming.isEmpty) {
    return null;
  }

  return SuggestedWorkout(
    workout: upcoming.first,
    isCatchUp: false,
    missedCount: 0,
  );
});

class SuggestedWorkout {
  const SuggestedWorkout({
    required this.workout,
    required this.isCatchUp,
    required this.missedCount,
  });

  final PlannedWorkout workout;
  final bool isCatchUp;
  final int missedCount;
}
