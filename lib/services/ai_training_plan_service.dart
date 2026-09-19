import '../models/training_plan.dart';
import '../models/training_plan_request.dart';

abstract class AITrainingPlanService {
  Future<TrainingPlan> generatePlan(TrainingPlanRequest request);
}

/// Deterministic, periodized coaching engine. A remote coach can later replace
/// this implementation without changing the request, model, provider, or UI.
class MockAITrainingPlanService implements AITrainingPlanService {
  const MockAITrainingPlanService();

  @override
  Future<TrainingPlan> generatePlan(TrainingPlanRequest request) async {
    final raceDate = _day(request.raceDate);
    final goalKm = _goalKm(request.goal);
    final totalWeeks = _weeksToRace(raceDate);
    final profile = _Profile(request, goalKm);
    final racePace = _racePace(request, goalKm);
    final weeks = <TrainingWeek>[];

    for (var index = 0; index < totalWeeks; index++) {
      final phase = _phase(index, totalWeeks);
      final workouts = phase == _Phase.race
          ? _raceWeek(request, raceDate, racePace, profile)
          : _trainingWeek(
              request,
              raceDate,
              index,
              totalWeeks,
              phase,
              profile,
              racePace,
            );
      workouts.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
      weeks.add(
        TrainingWeek(
          weekNumber: index + 1,
          focus: '${_goalLabel(request.goal)} ${_phaseLabel(phase)}',
          workouts: workouts,
        ),
      );
    }
    final workouts = weeks.expand((week) => week.workouts).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return TrainingPlan(
      id: 'ai-plan-${raceDate.millisecondsSinceEpoch}-${request.goal.name}',
      name: '${_goalLabel(request.goal)} Training Plan',
      goalDistanceKm: goalKm,
      workouts: workouts,
      goal: request.goal,
      raceDate: raceDate,
      targetTimeSeconds: request.targetTimeSeconds,
      createdAt: DateTime.now(),
      currentWeeklyMileageKm: profile.weekly,
      currentLongestRunKm: profile.longest,
      weeks: weeks,
    );
  }

  List<PlannedWorkout> _trainingWeek(
    TrainingPlanRequest request,
    DateTime raceDate,
    int index,
    int totalWeeks,
    _Phase phase,
    _Profile profile,
    double? racePace,
  ) {
    final number = index + 1;
    final start = _weekStart(raceDate, index, totalWeeks);
    final recovery = phase == _Phase.recovery;
    final multiplier = recovery ? .78 : 1.0;
    final easyPace = _pace(racePace, 1.22);
    final easyDistance = _easyDistance(request.goal, profile) * multiplier;
    final workouts = <PlannedWorkout>[
      _workout(
        'w$number-easy',
        start,
        WorkoutType.easyRun,
        easyDistance,
        easyPace,
        'Easy aerobic run at conversational effort. Build durability without accumulating fatigue.',
      ),
    ];
    if (request.trainingDaysPerWeek >= 3) {
      final intervals =
          phase == _Phase.base ||
          phase == _Phase.specific ||
          (request.goal == TrainingGoal.fiveK && phase == _Phase.peak);
      workouts.add(
        intervals
            ? _workout(
                'w$number-intervals',
                start.add(const Duration(days: 2)),
                WorkoutType.intervals,
                _qualityDistance(request.goal) * multiplier,
                _intervalPace(request.goal, racePace),
                _intervalDescription(request.goal, phase),
              )
            : _tempo(
                request,
                number,
                start.add(const Duration(days: 2)),
                racePace,
                multiplier,
              ),
      );
    }
    if (request.trainingDaysPerWeek >= 4) {
      workouts.add(
        _workout(
          'w$number-easy-2',
          start.add(const Duration(days: 4)),
          WorkoutType.easyRun,
          easyDistance * .8,
          easyPace,
          'Short easy run for aerobic volume and recovery.',
        ),
      );
    }
    workouts.add(
      _workout(
        'w$number-long',
        start.add(const Duration(days: 5)),
        WorkoutType.longRun,
        _longRun(request.goal, profile, index, totalWeeks, phase),
        easyPace,
        _longRunDescription(request.goal, phase),
      ),
    );
    return workouts;
  }

  List<PlannedWorkout> _raceWeek(
    TrainingPlanRequest request,
    DateTime raceDate,
    double? racePace,
    _Profile profile,
  ) {
    final week = _weeksToRace(raceDate);
    final workouts = <PlannedWorkout>[
      _workout(
        'w$week-easy',
        raceDate.subtract(const Duration(days: 4)),
        WorkoutType.easyRun,
        _easyDistance(request.goal, profile) * .55,
        _pace(racePace, 1.22),
        'Easy taper run. Finish fresh; this is not a fitness test.',
      ),
      if (request.trainingDaysPerWeek >= 3)
        _workout(
          'w$week-sharpen',
          raceDate.subtract(const Duration(days: 2)),
          WorkoutType.intervals,
          _taperDistance(request.goal),
          _intervalPace(request.goal, racePace),
          'Brief race-week sharpening with full recovery. Stay controlled and finish fresh.',
        ),
      _workout(
        'w$week-race',
        raceDate,
        WorkoutType.race,
        _goalKm(request.goal),
        racePace,
        'Race day. Start within your planned effort, fuel as practised, and let the race be the week\'s key workout.',
      ),
    ];
    return workouts;
  }

  PlannedWorkout _tempo(
    TrainingPlanRequest request,
    int week,
    DateTime date,
    double? racePace,
    double multiplier,
  ) {
    return _workout(
      'w$week-tempo',
      date,
      WorkoutType.tempo,
      _tempoDistance(request.goal) * multiplier,
      _tempoPace(request.goal, racePace),
      _tempoDescription(request.goal),
    );
  }

  PlannedWorkout _workout(
    String id,
    DateTime date,
    WorkoutType type,
    double distance,
    double? pace,
    String description,
  ) {
    return PlannedWorkout(
      id: id,
      scheduledDate: _day(date),
      type: type,
      targetDistanceKm: (distance * 10).round() / 10,
      targetPaceMinPerKm: _validPace(pace) ? pace : null,
      description: description,
    );
  }

  double _longRun(
    TrainingGoal goal,
    _Profile p,
    int index,
    int total,
    _Phase phase,
  ) {
    final buildWeeks = total > 2 ? total - 2 : 0;
    final start = p.longest > 0 ? p.longest : _startLongRun(goal, p.weekly);
    final desiredPeak = switch (goal) {
      TrainingGoal.fiveK => 10.0,
      TrainingGoal.tenK => 16.0,
      TrainingGoal.halfMarathon => 28.0,
      TrainingGoal.marathon => 32.0,
    };
    final weeklyStep = switch (goal) {
      TrainingGoal.fiveK => .75,
      TrainingGoal.tenK => 1.0,
      TrainingGoal.halfMarathon => 1.5,
      TrainingGoal.marathon => 2.0,
    };
    final safePeak = start + buildWeeks * weeklyStep + start * buildWeeks * .04;
    // Do not assume that weekly mileage can rise without limit simply because
    // the calendar allows it; sparse history remains a conservative case.
    final experiencePeak =
        p.weekly > 0 ? p.weekly * .75 + buildWeeks : start + buildWeeks;
    final peak = [desiredPeak, safePeak, experiencePeak]
        .reduce((lowest, value) => lowest < value ? lowest : value);
    final progress = buildWeeks == 0
        ? 0.0
        : index.clamp(0, buildWeeks).toDouble() / buildWeeks;
    var distance = start + (peak - start) * progress;
    if (phase == _Phase.recovery) distance *= .78;
    if (phase == _Phase.taper) distance *= .58;
    return distance;
  }

  double _startLongRun(TrainingGoal goal, double weekly) {
    final minimum = switch (goal) {
      TrainingGoal.fiveK => 4.0,
      TrainingGoal.tenK => 5.0,
      TrainingGoal.halfMarathon => 7.0,
      TrainingGoal.marathon => 8.0,
    };
    return weekly * .3 > minimum ? weekly * .3 : minimum;
  }

  _Phase _phase(int index, int total) {
    if (index == total - 1) return _Phase.race;
    if (index == total - 2) return _Phase.taper;
    if (total >= 6 && (index + 1) % 4 == 0) return _Phase.recovery;
    final progress = index / (total - 2).clamp(1, total);
    if (progress < .30) return _Phase.base;
    if (progress < .60) return _Phase.build;
    if (progress < .85) return _Phase.specific;
    return _Phase.peak;
  }

  double? _racePace(TrainingPlanRequest request, double distance) {
    if (request.targetTimeSeconds != null) {
      // Seconds -> minutes -> minutes per kilometre. This is the unit boundary.
      final pace = request.targetTimeSeconds! / 60.0 / distance;
      if (_validPace(pace)) return pace;
      throw ArgumentError.value(
        request.targetTimeSeconds,
        'targetTimeSeconds',
        'does not produce a realistic running pace for the chosen distance',
      );
    }
    final recent = request.fitnessSummary?.averagePaceMinPerKm;
    return _validPace(recent) ? recent : null;
  }

  bool _validPace(double? pace) =>
      pace != null && pace.isFinite && pace >= 2.3 && pace <= 15.0;
  double? _pace(double? base, double factor) =>
      base == null ? null : base * factor;
  double? _intervalPace(TrainingGoal goal, double? pace) =>
      _pace(pace, switch (goal) {
        TrainingGoal.fiveK => .96,
        TrainingGoal.tenK => .98,
        TrainingGoal.halfMarathon => .99,
        TrainingGoal.marathon => .98,
      });
  double? _tempoPace(TrainingGoal goal, double? pace) =>
      _pace(pace, switch (goal) {
        TrainingGoal.fiveK => 1.08,
        TrainingGoal.tenK => 1.05,
        TrainingGoal.halfMarathon => 1.02,
        TrainingGoal.marathon => .94,
      });

  int _weeksToRace(DateTime raceDate) =>
      (raceDate.difference(_day(DateTime.now())).inDays / 7)
          .ceil()
          .clamp(1, 16)
          .toInt();
  DateTime _weekStart(DateTime race, int index, int total) {
    final monday = race.subtract(Duration(days: race.weekday - 1));
    return _day(monday.subtract(Duration(days: (total - 1 - index) * 7)));
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
  double _goalKm(TrainingGoal goal) => switch (goal) {
    TrainingGoal.fiveK => 5,
    TrainingGoal.tenK => 10,
    TrainingGoal.halfMarathon => 21.1,
    TrainingGoal.marathon => 42.2,
  };
  double _easyDistance(TrainingGoal goal, _Profile p) {
    final minimum = switch (goal) {
      TrainingGoal.fiveK => 3.0,
      TrainingGoal.tenK => 4.0,
      TrainingGoal.halfMarathon => 5.0,
      TrainingGoal.marathon => 6.0,
    };
    final base = p.average > 0 ? p.average : p.longest * .55;
    return base.clamp(minimum, p.longest > 0 ? p.longest : minimum).toDouble();
  }

  double _qualityDistance(TrainingGoal goal) => switch (goal) {
    TrainingGoal.fiveK => 5,
    TrainingGoal.tenK => 6.5,
    TrainingGoal.halfMarathon => 8,
    TrainingGoal.marathon => 9,
  };
  double _tempoDistance(TrainingGoal goal) => switch (goal) {
    TrainingGoal.fiveK => 4.5,
    TrainingGoal.tenK => 6,
    TrainingGoal.halfMarathon => 8,
    TrainingGoal.marathon => 10,
  };
  double _taperDistance(TrainingGoal goal) => switch (goal) {
    TrainingGoal.fiveK => 3,
    TrainingGoal.tenK => 4,
    TrainingGoal.halfMarathon => 4.5,
    TrainingGoal.marathon => 5,
  };
  String _intervalDescription(TrainingGoal goal, _Phase phase) =>
      phase == _Phase.base
      ? 'Controlled running-economy repetitions with easy recovery. Finish composed, never sprinted.'
      : switch (goal) {
          TrainingGoal.fiveK => '400–1000 m repetitions around controlled 5K effort. Include warm-up and cooldown.',
          TrainingGoal.tenK => '800 m–2 km repetitions around 10K effort. Build rhythm, not exhaustion.',
          TrainingGoal.halfMarathon => 'Cruise intervals near threshold with short recovery; practise sustainable form.',
          TrainingGoal.marathon => 'Controlled aerobic intervals below all-out effort so the long run remains high quality.',
        };
  String _tempoDescription(TrainingGoal goal) => switch (goal) {
    TrainingGoal.fiveK => 'Controlled threshold run. Strong and sustainable; finish feeling you could complete another short block.',
    TrainingGoal.tenK => 'Sustained threshold work. Stay smooth rather than chasing a hard final kilometre.',
    TrainingGoal.halfMarathon => 'Cruise tempo or half-marathon-pace blocks. Practise sustainable effort and fueling rhythm.',
    TrainingGoal.marathon => 'Marathon-specific steady work. Practise relaxed form and nutrition without turning this into a race.',
  };
  String _longRunDescription(TrainingGoal goal, _Phase phase) {
    if (phase == _Phase.recovery) {
      return 'Reduced long aerobic run for recovery. Keep it genuinely easy so adaptation can catch up.';
    }
    if (phase == _Phase.taper) {
      return 'Short taper run. Stay relaxed and finish with plenty left for race day.';
    }
    return switch (goal) {
      TrainingGoal.fiveK =>
        'Easy longer aerobic run to build durability and support speed work.',
      TrainingGoal.tenK => 'Progressive long aerobic run. This may exceed 10K; keep the effort easy.',
      TrainingGoal.halfMarathon => 'Long aerobic endurance run. Practise fueling and steady pacing for fatigue resistance.',
      TrainingGoal.marathon => 'Long aerobic endurance run. Practise fueling, hydration, and patient marathon effort; do not race it.',
    };
  }

  String _goalLabel(TrainingGoal goal) => switch (goal) {
    TrainingGoal.fiveK => '5K',
    TrainingGoal.tenK => '10K',
    TrainingGoal.halfMarathon => 'Half Marathon',
    TrainingGoal.marathon => 'Marathon',
  };
  String _phaseLabel(_Phase phase) => switch (phase) {
    _Phase.base => 'base and running economy',
    _Phase.build => 'aerobic build and threshold',
    _Phase.specific => 'race-specific endurance',
    _Phase.peak => 'peak and sharpening',
    _Phase.recovery => 'recovery and adaptation',
    _Phase.taper => 'taper',
    _Phase.race => 'race week',
  };
}

enum _Phase { base, build, specific, peak, recovery, taper, race }

class _Profile {
  _Profile(TrainingPlanRequest request, double goal)
    : weekly =
          (request.currentWeeklyMileageKm ??
                  request.fitnessSummary?.recentWeeklyMileageKm ??
                  0)
              .clamp(0, double.infinity)
              .toDouble(),
      longest =
          (request.currentLongestRunKm ??
                  request.fitnessSummary?.longestRunKm ??
                  0)
              .clamp(0, double.infinity)
              .toDouble(),
      average = (request.fitnessSummary?.averageDistanceKm ?? goal * .45)
          .clamp(0, double.infinity)
          .toDouble();
  final double weekly;
  final double longest;
  final double average;
}
