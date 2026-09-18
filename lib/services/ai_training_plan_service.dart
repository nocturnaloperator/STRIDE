import '../models/training_plan.dart';
import '../models/training_plan_request.dart';

abstract class AITrainingPlanService {
  Future<TrainingPlan> generatePlan(
    TrainingPlanRequest request,
  );
}

class MockAITrainingPlanService implements AITrainingPlanService {
  const MockAITrainingPlanService();

  @override
  Future<TrainingPlan> generatePlan(
    TrainingPlanRequest request,
  ) async {
    final goalDistance = _goalDistanceKm(request.goal);
    final totalWeeks = _weeksUntilRace(request.raceDate);

    final weeks = <TrainingWeek>[];

    for (var week = 1; week <= totalWeeks; week++) {
      weeks.add(
        TrainingWeek(
          weekNumber: week,
          focus: _weekFocus(
            request.goal,
            week,
            totalWeeks,
          ),
          workouts: _createWeekWorkouts(
            request,
            week,
            totalWeeks,
          ),
        ),
      );
    }

    final workouts = weeks
        .expand((week) => week.workouts)
        .toList();

    return TrainingPlan(
      id: 'ai-plan-${DateTime.now().millisecondsSinceEpoch}',
      name: _planName(request.goal),
      goalDistanceKm: goalDistance,
      workouts: workouts,
      goal: request.goal,
      raceDate: request.raceDate,
      targetTimeSeconds: request.targetTimeSeconds,
      createdAt: DateTime.now(),
      currentWeeklyMileageKm:
          request.currentWeeklyMileageKm,
      currentLongestRunKm:
          request.currentLongestRunKm,
      weeks: weeks,
    );
  }

  List<PlannedWorkout> _createWeekWorkouts(
    TrainingPlanRequest request,
    int week,
    int totalWeeks,
  ) {
    if (request.goal == TrainingGoal.fiveK) {
      return _create5KWeek(
        request,
        week,
        totalWeeks,
      );
    }

    return _createDistanceRaceWeek(
      request,
      week,
      totalWeeks,
    );
  }

  // ------------------------------------------------------------
  // 5K TRAINING
  // ------------------------------------------------------------

  List<PlannedWorkout> _create5KWeek(
    TrainingPlanRequest request,
    int week,
    int totalWeeks,
  ) {
    final raceWeek = week == totalWeeks;

    if (raceWeek) {
      return [
        _createWorkout(
          id: 'w$week-easy',
          date: _dateForWeek(
            request.raceDate,
            week,
            2,
          ),
          type: WorkoutType.easyRun,
          distanceKm: 3.0,
          description:
              'Easy shakeout run. Keep the effort relaxed.',
        ),
        _createWorkout(
          id: 'w$week-race',
          date: request.raceDate,
          type: WorkoutType.longRun,
          distanceKm: 5.0,
          description:
              '5K race day. Start controlled and build effort gradually.',
        ),
      ];
    }

    final longestRecent =
        request.currentLongestRunKm ?? 5.0;

    final easyDistance =
        _fiveKEasyDistance(longestRecent);

    final longRunDistance =
        _fiveKLongRunDistance(
      longestRecent,
      week,
      totalWeeks,
    );

    final workouts = <PlannedWorkout>[
      _createWorkout(
        id: 'w$week-easy',
        date: _dateForWeek(
          request.raceDate,
          week,
          1,
        ),
        type: WorkoutType.easyRun,
        distanceKm: easyDistance,
        description:
            'Easy aerobic run. Conversational effort.',
      ),
    ];

    if (request.trainingDaysPerWeek >= 3) {
      workouts.add(
        _createWorkout(
          id: 'w$week-speed',
          date: _dateForWeek(
            request.raceDate,
            week,
            3,
          ),
          type: WorkoutType.intervals,
          distanceKm: _fiveKIntervalSessionDistance(
            week,
            totalWeeks,
          ),
          targetPaceMinPerKm:
              _fiveKIntervalPace(request),
          description:
              _fiveKIntervalDescription(
            week,
            totalWeeks,
          ),
        ),
      );
    }

    if (request.trainingDaysPerWeek >= 4) {
      workouts.add(
        _createWorkout(
          id: 'w$week-tempo',
          date: _dateForWeek(
            request.raceDate,
            week,
            5,
          ),
          type: WorkoutType.tempo,
          distanceKm:
              _fiveKTempoDistance(
            week,
            totalWeeks,
          ),
          targetPaceMinPerKm:
              _fiveKTempoPace(request),
          description:
              'Controlled threshold effort. '
              'Hard but sustainable; do not race the workout.',
        ),
      );
    }

    if (request.trainingDaysPerWeek >= 3) {
      workouts.add(
        _createWorkout(
          id: 'w$week-long',
          date: _dateForWeek(
            request.raceDate,
            week,
            6,
          ),
          type: WorkoutType.longRun,
          distanceKm: longRunDistance,
          description:
              'Easy longer aerobic run. '
              'Keep the effort controlled.',
        ),
      );
    }

    return workouts;
  }

  double _fiveKEasyDistance(
    double longestRecent,
  ) {
    final distance = longestRecent * 0.55;

    if (distance < 3.0) {
      return 3.0;
    }

    if (distance > 7.0) {
      return 7.0;
    }

    return distance;
  }

  double _fiveKLongRunDistance(
    double longestRecent,
    int week,
    int totalWeeks,
  ) {
    final startingDistance =
        longestRecent.clamp(4.0, 8.0);

    const peakDistance = 8.0;

    final progress =
        totalWeeks <= 1
            ? 1.0
            : (week - 1) / (totalWeeks - 1);

    final distance =
        startingDistance +
        (peakDistance - startingDistance) *
            progress;

    return distance.clamp(5.0, 8.0);
  }

  double _fiveKIntervalSessionDistance(
    int week,
    int totalWeeks,
  ) {
    final progress =
        totalWeeks <= 1
            ? 1.0
            : (week - 1) / (totalWeeks - 1);

    if (progress < 0.35) {
      return 4.5;
    }

    if (progress < 0.70) {
      return 5.0;
    }

    return 5.5;
  }

  String _fiveKIntervalDescription(
    int week,
    int totalWeeks,
  ) {
    final progress =
        totalWeeks <= 1
            ? 1.0
            : (week - 1) / (totalWeeks - 1);

    if (progress < 0.35) {
      return 'Speed introduction: '
          '6 × 1 minute hard with 2 minutes easy recovery. '
          'Include warm-up and cooldown.';
    }

    if (progress < 0.70) {
      return '5K-specific intervals: '
          '5 × 800 m at controlled 5K effort '
          'with easy recovery between repetitions. '
          'Include warm-up and cooldown.';
    }

    return '5K sharpening: '
        '6 × 400 m around 5K effort with easy recovery. '
        'Stay fast and controlled rather than sprinting.';
  }

  double? _fiveKIntervalPace(
    TrainingPlanRequest request,
  ) {
    final racePace =
        _estimatedRacePace(request);

    if (racePace == null) {
      return null;
    }

    return racePace * 0.96;
  }

  double _fiveKTempoDistance(
    int week,
    int totalWeeks,
  ) {
    final progress =
        totalWeeks <= 1
            ? 1.0
            : (week - 1) / (totalWeeks - 1);

    if (progress < 0.35) {
      return 3.0;
    }

    if (progress < 0.70) {
      return 4.0;
    }

    return 4.5;
  }

  double? _fiveKTempoPace(
    TrainingPlanRequest request,
  ) {
    final racePace =
        _estimatedRacePace(request);

    if (racePace == null) {
      return null;
    }

    return racePace * 1.08;
  }

  double? _estimatedRacePace(
    TrainingPlanRequest request,
  ) {
    final targetTime = request.targetTimeSeconds;

    if (targetTime != null && targetTime > 0) {
      return targetTime / 60.0 / _goalDistanceKm(request.goal);
    }

    final recentPace =
        request.fitnessSummary?.averagePaceMinPerKm;

    if (recentPace == null || recentPace <= 0) {
      return null;
    }

    return recentPace;
  }

  // ------------------------------------------------------------
  // 10K / HALF / MARATHON FOUNDATION
  // ------------------------------------------------------------

  List<PlannedWorkout> _createDistanceRaceWeek(
    TrainingPlanRequest request,
    int week,
    int totalWeeks,
  ) {
    final raceWeek = week == totalWeeks;

    if (raceWeek) {
      return [
        _createWorkout(
          id: 'w$week-easy',
          date: _dateForWeek(
            request.raceDate,
            week,
            3,
          ),
          type: WorkoutType.easyRun,
          distanceKm: 4.0,
          description:
              'Easy shakeout run.',
        ),
        _createWorkout(
          id: 'w$week-race',
          date: request.raceDate,
          type: WorkoutType.longRun,
          distanceKm:
              _goalDistanceKm(request.goal),
          description:
              'Race day.',
        ),
      ];
    }

    final longestRecent =
        request.currentLongestRunKm ?? 5.0;

    final longRunDistance =
        _longRunDistance(
      request.goal,
      longestRecent,
      week,
      totalWeeks,
    );

    final easyDistance =
        _easyRunDistance(
      request.goal,
      longestRecent,
    );

    final workouts = <PlannedWorkout>[
      _createWorkout(
        id: 'w$week-easy',
        date: _dateForWeek(
          request.raceDate,
          week,
          1,
        ),
        type: WorkoutType.easyRun,
        distanceKm: easyDistance,
        description:
            'Easy aerobic run at a comfortable effort.',
      ),
    ];

    if (request.trainingDaysPerWeek >= 3) {
      workouts.add(
        _createWorkout(
          id: 'w$week-quality',
          date: _dateForWeek(
            request.raceDate,
            week,
            3,
          ),
          type: WorkoutType.tempo,
          distanceKm:
              _tempoDistance(request.goal),
          targetPaceMinPerKm:
              _targetTempoPace(request),
          description:
              'Controlled tempo workout. '
              'Finish strong without racing.',
        ),
      );
    }

    if (request.trainingDaysPerWeek >= 4) {
      workouts.add(
        _createWorkout(
          id: 'w$week-long',
          date: _dateForWeek(
            request.raceDate,
            week,
            6,
          ),
          type: WorkoutType.longRun,
          distanceKm: longRunDistance,
          description:
              'Long aerobic run. Keep the effort controlled.',
        ),
      );
    }

    return workouts;
  }

  // ------------------------------------------------------------
  // COMMON HELPERS
  // ------------------------------------------------------------

  PlannedWorkout _createWorkout({
    required String id,
    required DateTime date,
    required WorkoutType type,
    double? distanceKm,
    double? targetPaceMinPerKm,
    String? description,
  }) {
    return PlannedWorkout(
      id: id,
      scheduledDate: date,
      type: type,
      targetDistanceKm: distanceKm,
      targetPaceMinPerKm: targetPaceMinPerKm,
      description: description,
    );
  }

  DateTime _dateForWeek(
    DateTime raceDate,
    int week,
    int weekday,
  ) {
    final raceMonday = raceDate.subtract(
      Duration(days: raceDate.weekday - 1),
    );

    final date = raceMonday
        .subtract(
          Duration(days: (week - 1) * 7),
        )
        .add(
          Duration(days: weekday - 1),
        );

    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  int _weeksUntilRace(DateTime raceDate) {
    final now = DateTime.now();
    final days = raceDate.difference(now).inDays;

    final weeks = (days / 7).ceil();

    if (weeks < 1) {
      return 1;
    }

    if (weeks > 16) {
      return 16;
    }

    return weeks;
  }

  double _goalDistanceKm(TrainingGoal goal) {
    switch (goal) {
      case TrainingGoal.fiveK:
        return 5.0;
      case TrainingGoal.tenK:
        return 10.0;
      case TrainingGoal.halfMarathon:
        return 21.1;
      case TrainingGoal.marathon:
        return 42.2;
    }
  }

  double _easyRunDistance(
    TrainingGoal goal,
    double longestRecent,
  ) {
    final base =
        longestRecent > 0
            ? longestRecent * 0.55
            : 5.0;

    final minimum = switch (goal) {
      TrainingGoal.fiveK => 3.0,
      TrainingGoal.tenK => 4.0,
      TrainingGoal.halfMarathon => 5.0,
      TrainingGoal.marathon => 6.0,
    };

    return base < minimum ? minimum : base;
  }

  double _tempoDistance(TrainingGoal goal) {
    switch (goal) {
      case TrainingGoal.fiveK:
        return 4.0;
      case TrainingGoal.tenK:
        return 5.0;
      case TrainingGoal.halfMarathon:
        return 7.0;
      case TrainingGoal.marathon:
        return 8.0;
    }
  }

  double _longRunDistance(
    TrainingGoal goal,
    double longestRecent,
    int week,
    int totalWeeks,
  ) {
    final goalDistance =
        _goalDistanceKm(goal);

    final startingPoint =
        longestRecent > 0
            ? longestRecent * 1.05
            : goalDistance * 0.35;

    final peakFraction = switch (goal) {
      TrainingGoal.fiveK => 0.9,
      TrainingGoal.tenK => 1.2,
      TrainingGoal.halfMarathon => 0.8,
      TrainingGoal.marathon => 0.75,
    };

    final peak =
        goalDistance * peakFraction;

    final progress =
        totalWeeks <= 1
            ? 1.0
            : (week - 1) /
                (totalWeeks - 1);

    final distance =
        startingPoint +
        (peak - startingPoint) *
            progress;

    final minimum =
        goal == TrainingGoal.marathon
            ? 10.0
            : 6.0;

    return distance < minimum
        ? minimum
        : distance;
  }

  double? _targetTempoPace(
    TrainingPlanRequest request,
  ) {
    final targetTime =
        request.targetTimeSeconds;

    if (targetTime != null &&
        targetTime > 0) {
      final raceDistance =
          _goalDistanceKm(request.goal);

      final racePace =
          targetTime / raceDistance;

      return racePace * 1.08;
    }

    final averagePace =
        request.fitnessSummary
            ?.averagePaceMinPerKm;

    if (averagePace == null) {
      return null;
    }

    return averagePace * 1.08;
  }

  String _weekFocus(
    TrainingGoal goal,
    int week,
    int totalWeeks,
  ) {
    if (week == totalWeeks) {
      return 'Race week and taper';
    }

    if (goal == TrainingGoal.fiveK) {
      if (week <= (totalWeeks / 3).ceil()) {
        return '5K base and speed foundation';
      }

      if (week <=
          (totalWeeks * 2 / 3).ceil()) {
        return '5K-specific speed and threshold';
      }

      return '5K sharpening';
    }

    if (week <= (totalWeeks / 3).ceil()) {
      return 'Base building';
    }

    if (week <=
        (totalWeeks * 2 / 3).ceil()) {
      return 'Build fitness';
    }

    return 'Peak and sharpen';
  }

  String _planName(TrainingGoal goal) {
    switch (goal) {
      case TrainingGoal.fiveK:
        return 'AI 5K Training Plan';
      case TrainingGoal.tenK:
        return 'AI 10K Training Plan';
      case TrainingGoal.halfMarathon:
        return 'AI Half Marathon Training Plan';
      case TrainingGoal.marathon:
        return 'AI Marathon Training Plan';
    }
  }
}

