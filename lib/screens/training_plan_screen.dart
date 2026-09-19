import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/training_plan.dart';
import '../providers/training_plan_provider.dart';
import '../utils/formatting.dart';

class TrainingPlanScreen extends ConsumerStatefulWidget {
  const TrainingPlanScreen({super.key});

  @override
  ConsumerState<TrainingPlanScreen> createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends ConsumerState<TrainingPlanScreen> {
  TrainingGoal _goal = TrainingGoal.fiveK;
  DateTime _raceDate = DateTime.now().add(const Duration(days: 42));
  int _trainingDaysPerWeek = 3;

  final TextEditingController _targetTimeController = TextEditingController();

  @override
  void dispose() {
    _targetTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(trainingPlanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Training plan')),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load plan: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (plan) => plan == null
            ? _PlanBuilder(
                goal: _goal,
                raceDate: _raceDate,
                trainingDaysPerWeek: _trainingDaysPerWeek,
                targetTimeController: _targetTimeController,
                onGoalChanged: (goal) {
                  setState(() => _goal = goal);
                },
                onRaceDateChanged: (date) {
                  setState(() => _raceDate = date);
                },
                onTrainingDaysChanged: (days) {
                  setState(() => _trainingDaysPerWeek = days);
                },
                onGenerate: _generatePlan,
              )
            : _PlanView(plan: plan),
      ),
    );
  }

  Future<void> _generatePlan() async {
    int? targetTimeSeconds;

    final targetText = _targetTimeController.text.trim();

    if (targetText.isNotEmpty) {
      targetTimeSeconds = _parseTargetTime(targetText);

      if (targetTimeSeconds == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter target time as MM:SS or H:MM:SS.')),
        );
        return;
      }
    }

    await ref
        .read(trainingPlanProvider.notifier)
        .generatePlan(
          goal: _goal,
          raceDate: _raceDate,
          trainingDaysPerWeek: _trainingDaysPerWeek,
          targetTimeSeconds: targetTimeSeconds,
        );
  }

  int? _parseTargetTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2 && parts.length != 3) {
      return null;
    }

    final values = parts.map(int.tryParse).toList();
    if (values.any((part) => part == null)) return null;
    final numbers = values.cast<int>();

    final hours = parts.length == 3 ? numbers[0] : 0;
    final minutes = parts.length == 3 ? numbers[1] : numbers[0];
    final seconds = parts.length == 3 ? numbers[2] : numbers[1];

    if (hours < 0 || minutes < 0 || seconds < 0 ||
        minutes >= 60 || seconds >= 60) {
      return null;
    }

    return hours * 3600 + minutes * 60 + seconds;
  }
}

class _PlanBuilder extends StatelessWidget {
  const _PlanBuilder({
    required this.goal,
    required this.raceDate,
    required this.trainingDaysPerWeek,
    required this.targetTimeController,
    required this.onGoalChanged,
    required this.onRaceDateChanged,
    required this.onTrainingDaysChanged,
    required this.onGenerate,
  });

  final TrainingGoal goal;
  final DateTime raceDate;
  final int trainingDaysPerWeek;
  final TextEditingController targetTimeController;
  final ValueChanged<TrainingGoal> onGoalChanged;
  final ValueChanged<DateTime> onRaceDateChanged;
  final ValueChanged<int> onTrainingDaysChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Build your training plan',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Stride will use your activity history and current fitness to build your plan.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),

        Text('Race goal', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        DropdownButtonFormField<TrainingGoal>(
          initialValue: goal,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Distance',
          ),
          items: const [
            DropdownMenuItem(value: TrainingGoal.fiveK, child: Text('5K')),
            DropdownMenuItem(value: TrainingGoal.tenK, child: Text('10K')),
            DropdownMenuItem(
              value: TrainingGoal.halfMarathon,
              child: Text('Half Marathon'),
            ),
            DropdownMenuItem(
              value: TrainingGoal.marathon,
              child: Text('Marathon'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onGoalChanged(value);
            }
          },
        ),

        const SizedBox(height: 20),

        Text('Race date', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        OutlinedButton.icon(
          onPressed: () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: raceDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );

            if (selected != null) {
              onRaceDateChanged(selected);
            }
          },
          icon: const Icon(Icons.calendar_today),
          label: Text(
            '${raceDate.day}/'
            '${raceDate.month}/'
            '${raceDate.year}',
          ),
        ),

        const SizedBox(height: 20),

        Text('Target time', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        TextField(
          controller: targetTimeController,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g. 25:00 for 5K',
            helperText: 'Optional. Use MM:SS or H:MM:SS.',
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Training days per week',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),

        DropdownButtonFormField<int>(
          initialValue: trainingDaysPerWeek,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: List.generate(4, (index) {
            final days = index + 3;

            return DropdownMenuItem(value: days, child: Text('$days days'));
          }),
          onChanged: (value) {
            if (value != null) {
              onTrainingDaysChanged(value);
            }
          },
        ),

        const SizedBox(height: 32),

        FilledButton.icon(
          onPressed: onGenerate,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generate AI plan'),
        ),
      ],
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
          'Goal: '
          '${plan.goalDistanceKm.toStringAsFixed(1)} km',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (plan.raceDate != null) ...[
          const SizedBox(height: 4),
          Text(
            'Race: '
            '${plan.raceDate!.day}/'
            '${plan.raceDate!.month}/'
            '${plan.raceDate!.year}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
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
                'You have '
                '${suggestion.missedCount} missed '
                '${suggestion.missedCount == 1 ? 'workout' : 'workouts'} '
                '— here\'s what to focus on next.',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ),
          _WorkoutCard(workout: suggestion.workout, highlighted: true),
        ],
        const SizedBox(height: 24),
        Text('Full schedule', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...plan.workouts.map(
          (workout) => _WorkoutCard(workout: workout, highlighted: false),
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
        '${workout.scheduledDate.day}/'
        '${workout.scheduledDate.month}';

    final details = <String>[
      if (workout.targetDistanceKm != null)
        '${workout.targetDistanceKm!.toStringAsFixed(1)} km',
      if (workout.targetPaceMinPerKm != null)
        '${formatPace(workout.targetPaceMinPerKm)} /km',
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
        subtitle: Text(details.isEmpty ? dateLabel : '$dateLabel · $details'),
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
      WorkoutType.race => 'Race day',
    };
  }
}
