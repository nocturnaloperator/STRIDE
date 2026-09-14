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
  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;

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

    debugPrint(
      'STRIDE: GPS position ${position.latitude}, ${position.longitude}',
    );

    final point = RoutePoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      altitude: position.altitude,
      speedMps: position.speed,
    );

    final lastPoint = state.route.isEmpty ? null : state.route.last;

    // Calculate the distance between the previous GPS point
    // and the new GPS point.
    final addedMeters = lastPoint == null
        ? 0.0
        : Geolocator.distanceBetween(
            lastPoint.latitude,
            lastPoint.longitude,
            point.latitude,
            point.longitude,
          );

    // Ignore obviously invalid GPS jumps.
    //
    // A single GPS glitch can otherwise add hundreds of meters
    // or even kilometers to a run.
    if (addedMeters > 200) {
      debugPrint(
        'STRIDE: Ignoring GPS jump of ${addedMeters.toStringAsFixed(1)}m',
      );

      state = state.copyWith(
        route: [...state.route, point],
      );

      return;
    }

    state = state.copyWith(
      route: [...state.route, point],
      distanceMeters: state.distanceMeters + addedMeters,
    );
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
  }
}