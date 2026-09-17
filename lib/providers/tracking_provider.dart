import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/activity.dart';
import '../services/location_service.dart';

/// Uses the real device GPS for activity tracking.
///
/// Permission checks, GPS availability, and location updates
/// are handled by LocationService.
final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService();
});

/// Holds any location/tracking error that occurs while recording.
final trackingErrorProvider = StateProvider<String?>((ref) => null);

/// Main provider for the current running activity.
final trackingProvider = NotifierProvider<TrackingNotifier, Activity>(
  TrackingNotifier.new,
);

class TrackingNotifier extends Notifier<Activity> {
  static const _paceWindow = Duration(seconds: 60);
  static const _paceMinimumDistanceMeters = 35.0;
  static const _paceMinimumDurationSeconds = 12.0;

  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;
  final List<_TrustedSegment> _recentSegments = [];

  @override
  Activity build() {
    ref.onDispose(_cleanup);
    return _idle();
  }

  /// Returns a fresh idle activity.
  Activity _idle() {
    return Activity(
      id: '',
      status: ActivityStatus.idle,
      route: const [],
      startedAt: DateTime.now(),
    );
  }

  void _resetGpsProcessing() {
    _recentSegments.clear();
  }

  /// Checks GPS and permissions, then starts recording.
  Future<void> start() async {
    debugPrint('STRIDE: start() called');

    // Prevent accidentally starting another activity.
    if (state.status == ActivityStatus.recording) {
      debugPrint('STRIDE: Already recording');
      return;
    }

    // Clean up anything left over from a previous attempt.
    _cleanup();
    _resetGpsProcessing();

    ref.read(trackingErrorProvider.notifier).state = null;

    final locationService = ref.read(locationServiceProvider);

    try {
      debugPrint('STRIDE: Checking location permission...');

      // This checks whether GPS is enabled and requests
      // the Android location permission when required.
      await locationService.ensureReady();

      debugPrint('STRIDE: Location permission ready');

      // Create the new activity only after location access
      // has been successfully verified.
      state = Activity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        status: ActivityStatus.recording,
        route: const [],
        startedAt: DateTime.now(),
      );

      debugPrint('STRIDE: Activity started');

      // Start the activity timer.
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (state.status == ActivityStatus.recording) {
            state = state.copyWith(
              durationSeconds: state.durationSeconds + 1,
            );
          }
        },
      );

      debugPrint('STRIDE: Timer started');

      // Start receiving real GPS positions.
      _positionSub = locationService.positionStream().listen(
        _onPosition,
        onError: _onLocationError,
        cancelOnError: false,
      );

      debugPrint('STRIDE: GPS stream started');
    } catch (error) {
      debugPrint('STRIDE: START ERROR: $error');

      // If permission is denied, GPS is disabled, or another
      // location error occurs, do not start the activity.
      _cleanup();

      ref.read(trackingErrorProvider.notifier).state = error.toString();

      state = _idle();

      rethrow;
    }
  }

  /// Handles each GPS position received from the device.
  void _onPosition(Position position) {
    // Ignore GPS updates unless the activity is actually recording.
    if (state.status != ActivityStatus.recording) {
      return;
    }

    final accuracy = position.accuracy.isFinite && position.accuracy >= 0
        ? position.accuracy
        : 100.0;
    debugPrint(
      'STRIDE: GPS position ${position.latitude}, ${position.longitude} '
      '(accuracy ${accuracy.toStringAsFixed(1)}m)',
    );

    final point = RoutePoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      altitude: position.altitude,
      speedMps: position.speed,
    );

    final lastPoint = state.route.isEmpty ? null : state.route.last;

    // The first usable fix establishes the route baseline. It contributes no
    // distance, regardless of its reported accuracy.
    if (lastPoint == null) {
      state = state.copyWith(route: [point]);
      return;
    }

    final addedMeters = Geolocator.distanceBetween(
      lastPoint.latitude,
      lastPoint.longitude,
      point.latitude,
      point.longitude,
    );
    final elapsedSeconds = point.timestamp
        .difference(lastPoint.timestamp)
        .inMilliseconds / 1000;
    if (elapsedSeconds <= 0) {
      debugPrint('STRIDE: Ignoring out-of-order GPS timestamp');
      return;
    }

    final impliedSpeedMps = addedMeters / elapsedSeconds;
    final minimumMovement = _minimumMovementMeters(accuracy);
    final maximumSpeed = _maximumTrustedSpeedMps(accuracy);

    // Accuracy is a confidence signal, not a hard acceptance rule. A poor
    // fix may still be used for plausible movement, while an excellent fix
    // is still rejected if it implies an impossible running speed.
    if (impliedSpeedMps > maximumSpeed) {
      debugPrint(
        'STRIDE: Ignoring GPS jump of ${addedMeters.toStringAsFixed(1)}m '
        'at ${impliedSpeedMps.toStringAsFixed(1)}m/s '
        '(accuracy ${accuracy.toStringAsFixed(1)}m)',
      );
      return;
    }

    // Nearby fixes are usually stationary GPS wander. Retaining the previous
    // trusted baseline lets real running movement accumulate naturally until
    // it clears this small, accuracy-aware threshold.
    if (addedMeters < minimumMovement) {
      _clearStaleLivePace(point.timestamp);
      return;
    }

    _recentSegments.add(_TrustedSegment(
      endedAt: point.timestamp,
      distanceMeters: addedMeters,
      durationSeconds: elapsedSeconds,
    ));
    final currentPace = _calculateCurrentPace(point.timestamp);

    state = state.copyWith(
      route: [...state.route, point],
      distanceMeters: state.distanceMeters + addedMeters,
      currentPaceMinPerKm: currentPace,
    );
  }

  /// Treat <=4m as excellent, while becoming progressively more cautious as
  /// uncertainty rises. These are deliberately small enough for normal runs.
  double _minimumMovementMeters(double accuracy) {
    if (accuracy <= 4) return 2.5;
    if (accuracy <= 10) return 3.5;
    if (accuracy <= 20) return 5.0;
    return 8.0;
  }

  /// Better fixes have a little more headroom for sprinting; poor fixes are
  /// checked more conservatively for improbable displacement.
  double _maximumTrustedSpeedMps(double accuracy) {
    if (accuracy <= 4) return 9.0;
    if (accuracy <= 10) return 8.5;
    if (accuracy <= 20) return 7.5;
    return 6.5;
  }

  double? _calculateCurrentPace(DateTime now) {
    final cutoff = now.subtract(_paceWindow);
    _recentSegments.removeWhere((segment) => segment.endedAt.isBefore(cutoff));
    final recentDistance = _recentSegments.fold<double>(
      0,
      (total, segment) => total + segment.distanceMeters,
    );
    final recentSeconds = _recentSegments.fold<double>(
      0,
      (total, segment) => total + segment.durationSeconds,
    );
    if (recentDistance < _paceMinimumDistanceMeters ||
        recentSeconds < _paceMinimumDurationSeconds) {
      return state.currentPaceMinPerKm;
    }

    final rawPace = (recentSeconds / 60) / (recentDistance / 1000);
    if (rawPace < 2.3 || rawPace > 20) return state.currentPaceMinPerKm;

    final previous = state.currentPaceMinPerKm;
    return previous == null ? rawPace : previous * 0.65 + rawPace * 0.35;
  }

  void _clearStaleLivePace(DateTime timestamp) {
    final lastTrustedAt = _recentSegments.isEmpty
        ? null
        : _recentSegments.last.endedAt;
    if (lastTrustedAt == null ||
        timestamp.difference(lastTrustedAt) > const Duration(seconds: 15)) {
      state = state.copyWith(clearCurrentPace: true);
    }
  }

  /// Handles errors coming from the GPS stream.
  void _onLocationError(Object error) {
    debugPrint('STRIDE: GPS ERROR: $error');

    if (state.status != ActivityStatus.recording) {
      return;
    }

    pause();

    ref.read(trackingErrorProvider.notifier).state = error.toString();
  }

  /// Pauses the current activity.
  void pause() {
    if (state.status != ActivityStatus.recording) {
      return;
    }

    debugPrint('STRIDE: Activity paused');

    state = state.copyWith(
      status: ActivityStatus.paused,
    );

    _positionSub?.pause();
  }

  /// Resumes a paused activity.
  void resume() {
    if (state.status != ActivityStatus.paused) {
      return;
    }

    debugPrint('STRIDE: Activity resumed');

    ref.read(trackingErrorProvider.notifier).state = null;

    state = state.copyWith(
      status: ActivityStatus.recording,
    );

    _positionSub?.resume();
  }

  /// Finishes the activity and returns the completed activity.
  Activity finish() {
    if (state.status != ActivityStatus.recording &&
        state.status != ActivityStatus.paused) {
      return state;
    }

    debugPrint('STRIDE: Activity finished');

    final completed = state.copyWith(
      status: ActivityStatus.finished,
      endedAt: DateTime.now(),
    );

    _cleanup();

    state = _idle();

    return completed;
  }

  /// Cancels timers and GPS subscriptions.
  void _cleanup() {
    _ticker?.cancel();
    _positionSub?.cancel();

    _ticker = null;
    _positionSub = null;
    _resetGpsProcessing();
  }
}

/// A distance contribution that has passed GPS quality checks.
class _TrustedSegment {
  const _TrustedSegment({
    required this.endedAt,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final DateTime endedAt;
  final double distanceMeters;
  final double durationSeconds;
}
