import 'package:flutter/foundation.dart';

enum ActivityStatus { idle, recording, paused, finished }

@immutable
class RoutePoint {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.speedMps,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitude;
  final double? speedMps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutePoint &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          timestamp == other.timestamp);

  @override
  int get hashCode => Object.hash(latitude, longitude, timestamp);
}

@immutable
class Activity {
  const Activity({
    required this.id,
    required this.status,
    required this.route,
    required this.startedAt,
    this.endedAt,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.pausedDurationSeconds = 0,
    this.currentPaceMinPerKm,
  });

  final String id;
  final ActivityStatus status;
  final List<RoutePoint> route;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distanceMeters;
  final int durationSeconds;
  final int pausedDurationSeconds;

  /// A smoothed pace based on recent trusted GPS movement.
  ///
  /// This intentionally remains separate from [paceMinPerKm], which is the
  /// average pace for the whole activity.
  final double? currentPaceMinPerKm;

  double get distanceKm => distanceMeters / 1000;

  Duration get movingDuration => Duration(seconds: durationSeconds);

  double? get paceMinPerKm {
    if (distanceMeters < 10) return null;

    final minutes = durationSeconds / 60;
    return minutes / (distanceMeters / 1000);
  }

  Activity copyWith({
    ActivityStatus? status,
    List<RoutePoint>? route,
    DateTime? endedAt,
    double? distanceMeters,
    int? durationSeconds,
    int? pausedDurationSeconds,
    double? currentPaceMinPerKm,
    bool clearCurrentPace = false,
  }) {
    return Activity(
      id: id,
      status: status ?? this.status,
      route: route ?? this.route,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pausedDurationSeconds:
          pausedDurationSeconds ?? this.pausedDurationSeconds,
      currentPaceMinPerKm: clearCurrentPace
          ? null
          : currentPaceMinPerKm ?? this.currentPaceMinPerKm,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Activity &&
          id == other.id &&
          status == other.status &&
          startedAt == other.startedAt &&
          endedAt == other.endedAt &&
          distanceMeters == other.distanceMeters &&
          durationSeconds == other.durationSeconds &&
          pausedDurationSeconds == other.pausedDurationSeconds &&
          currentPaceMinPerKm == other.currentPaceMinPerKm &&
          listEquals(route, other.route));

  @override
  int get hashCode => Object.hash(
        id,
        status,
        startedAt,
        endedAt,
        distanceMeters,
        durationSeconds,
        pausedDurationSeconds,
        currentPaceMinPerKm,
        Object.hashAll(route),
      );
}
