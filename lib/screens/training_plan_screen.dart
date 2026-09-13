import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
 
import '../models/training_plan.dart';
import '../providers/training_plan_provider.dart';
 
class TrainingPlanScreen extends ConsumerWidget {
  const TrainingPlanScreen({super.key});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(trainingPlanProvider);
 
    return Scaffold(
      appBar: AppBar(title: const Text('Training plan')),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load plan: $error')),
        data: (plan) => plan == null
            ? _NoPlanState(
                onCreate: () => ref
                    .read(trainingPlanProvider.notifier)
                    .setPlan(_generateSample10kPlan()),
              )
            : _PlanView(plan: plan),
      ),
    );
  }
}
 
/// Quick-start plan generator — a stand-in until a real plan-builder UI
/// exists (pick a race distance, weeks, days per week). Produces a
/// 4-week, 3-day-a-week 10K plan starting today: easy run, tempo run,
/// long run, repeated weekly with the long run growing each week.
TrainingPlan _generateSample10kPlan() {
  final today = DateTime.now();
  final workouts = <PlannedWorkout>[];
  var workoutIndex = 0;
 
  for (var week = 0; week < 4; week++) {
    for (var day = 0; day < 3; day++) {
      final dayOffset = week * 7 + (day * 2 + 1); // spread across the week
 
      var type = WorkoutType.easyRun;
      var distanceKm = 5.0;
      double? paceMinPerKm;
 
      if (day == 1) {
        type = WorkoutType.tempo;
        distanceKm = 6;
        paceMinPerKm = 5.5;
      } else if (day == 2) {
        type = WorkoutType.longRun;
        distanceKm = 9.0 + week;
      }
 
      workouts.add(
        PlannedWorkout(
          id: 'w${workoutIndex++}',
          scheduledDate: today.add(Duration(days: dayOffset)),
          type: type,
          targetDistanceKm: distanceKm,
          targetPaceMinPerKm: paceMinPerKm,
        ),
      );
    }
  }
 
  return TrainingPlan(
    id: 'plan_${today.millisecondsSinceEpoch}',
    name: '4-week 10K builder',
    goalDistanceKm: 10,
    workouts: workouts,
  );
}
 
class _NoPlanState extends StatelessWidget {
  const _NoPlanState({required this.onCreate});
  final VoidCallback onCreate;
 
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No training plan yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start with a sample 4-week 10K builder — a full plan-builder UI comes later.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onCreate,
              child: const Text('Create sample plan'),
            ),
          ],
        ),
      ),
    );
  }
}
 
class _PlanView extends ConsumerWidget {
  const _PlanView({required this.plan});
  final TrainingPlan plan;
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = ref.watch(suggestedWorkoutProvider);
 
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Goal: ${plan.goalDistanceKm.toStringAsFixed(0)} km',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: plan.progress),
        const SizedBox(height: 4),
        Text(
          '${(plan.progress * 100).toStringAsFixed(0)}% complete',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Text('Next workout', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (suggestion == null)
          const Text('All caught up — no upcoming workouts.')
        else ...[
          if (suggestion.isCatchUp)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'You have ${suggestion.missedCount} missed '
                '${suggestion.missedCount == 1 ? 'workout' : 'workouts'} — '
                "here's what to focus on next.",
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ),
          _WorkoutCard(workout: suggestion.workout, highlighted: true),
        ],
        const SizedBox(height: 24),
        Text('Full schedule', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...plan.workouts.map(
          (w) => _WorkoutCard(workout: w, highlighted: false),
        ),
      ],
    );
  }
}
 
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout, required this.highlighted});
  final PlannedWorkout workout;
  final bool highlighted;
 
  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${workout.scheduledDate.day}/${workout.scheduledDate.month}';
    final details = <String>[
      if (workout.targetDistanceKm != null)
        '${workout.targetDistanceKm!.toStringAsFixed(1)} km',
      if (workout.targetPaceMinPerKm != null)
        '${workout.targetPaceMinPerKm!.toStringAsFixed(1)} min/km',
    ].join(' · ');
 
    return Card(
      color: highlighted
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          workout.isCompleted ? Icons.check_circle : Icons.circle_outlined,
          color: workout.isCompleted ? Colors.green : null,
        ),
        title: Text(_typeLabel(workout.type)),
        subtitle: Text(
          details.isEmpty ? dateLabel : '$dateLabel · $details',
        ),
      ),
    );
  }
 
  String _typeLabel(WorkoutType type) {
    return switch (type) {
      WorkoutType.rest => 'Rest day',
      WorkoutType.easyRun => 'Easy run',
      WorkoutType.longRun => 'Long run',
      WorkoutType.tempo => 'Tempo run',
      WorkoutType.intervals => 'Intervals',
      WorkoutType.crossTrain => 'Cross-training',
    };
  }
}