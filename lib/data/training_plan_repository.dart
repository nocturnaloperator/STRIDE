import '../models/training_plan.dart';

/// Persists and retrieves the runner's active training plan.
abstract class TrainingPlanRepository {
  /// Returns null if the runner has not created a plan yet.
  Future<TrainingPlan?> fetchActivePlan();

  /// Saves the active training plan.
  Future<void> savePlan(TrainingPlan plan);
}

/// Temporary in-memory implementation.
///
/// This keeps the current Training Plan behavior working while
/// we build and test the AI Coach pipeline. SQLite persistence
/// can be added after the generation flow is verified.
class InMemoryTrainingPlanRepository
    implements TrainingPlanRepository {
  TrainingPlan? _activePlan;

  @override
  Future<TrainingPlan?> fetchActivePlan() async {
    return _activePlan;
  }

  @override
  Future<void> savePlan(TrainingPlan plan) async {
    _activePlan = plan;
  }
}