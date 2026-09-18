import 'runner_fitness_summary.dart';
import 'training_plan.dart';

/// Everything the AI coach needs to generate a training plan.
class TrainingPlanRequest {
  const TrainingPlanRequest({
    required this.goal,
    required this.raceDate,
    required this.trainingDaysPerWeek,
    this.targetTimeMinutes,
    this.currentWeeklyMileageKm,
    this.currentLongestRunKm,
    this.fitnessSummary,
  });

  final TrainingGoal goal;
  final DateTime raceDate;
  final int trainingDaysPerWeek;
  final int? targetTimeMinutes;

  final double? currentWeeklyMileageKm;
  final double? currentLongestRunKm;

  final RunnerFitnessSummary? fitnessSummary;
}