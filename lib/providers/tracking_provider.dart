import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../models/activity.dart';

/// Swap for `GeolocatorLocationService()` the moment you're testing on a
/// real device instead of an emulator — nothing else in this file, or
/// any screen built on top of it, needs to change.
final locationServiceProvider = Provider<LocationService>((ref) {
  return MockLocationService();
});

/// Surfaces a mid-run location failure (permission revoked, GPS lost)
/// without derailing the activity's own state. The tracking screen
/// watches this to show a snackbar/banner, then it's cleared.
final trackingErrorProvider = StateProvider<String?>((ref) => null);

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

  Activity _idle() => Activity(
        id: '',
        status: ActivityStatus.idle,
        route: const [],
        startedAt: DateTime.now(),
      );

  /// Requests permission and starts recording.
  Future<void> start() async {
    final locationService = ref.read(locationServiceProvider);
    await locationService.ensureReady();

    ref.read(trackingErrorProvider.notifier).state = null;

    state = Activity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      status: ActivityStatus.recording,
      route: const [],
      startedAt: DateTime.now(),
    );

    _ticker?.cancel();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == ActivityStatus.recording) {
        state = state.copyWith(
          durationSeconds: state.durationSeconds + 1,
        );
      }
    });

    _positionSub = locationService.positionStream().listen(
      _onPosition,
      onError: (Object error) {
        pause();
        ref.read(trackingErrorProvider.notifier).state = error.toString();
      },
    );
  }

  void _onPosition(Position position) {
    final point = RoutePoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      altitude: position.altitude,
      speedMps: position.speed,
    );

    final last = state.route.isEmpty ? null : state.route.last;

    final addedMeters = last == null
        ? 0.0
        : Geolocator.distanceBetween(
            last.latitude,
            last.longitude,
            point.latitude,
            point.longitude,
          );

    state = state.copyWith(
      route: [...state.route, point],
      distanceMeters: state.distanceMeters + addedMeters,
    );
  }

  void pause() {
    if (state.status != ActivityStatus.recording) return;

    state = state.copyWith(
      status: ActivityStatus.paused,
    );

    _positionSub?.pause();
  }

  void resume() {
    if (state.status != ActivityStatus.paused) return;

    state = state.copyWith(
      status: ActivityStatus.recording,
    );

    _positionSub?.resume();
  }

  /// Ends the activity and returns the completed activity.
  Activity finish() {
    final completed = state.copyWith(
      status: ActivityStatus.finished,
      endedAt: DateTime.now(),
    );

    _cleanup();
    state = _idle();

    return completed;
  }

  void _cleanup() {
    _ticker?.cancel();
    _positionSub?.cancel();

    _ticker = null;
    _positionSub = null;
  }
}