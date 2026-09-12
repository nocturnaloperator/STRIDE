import 'package:latlong2/latlong.dart';
 
/// Represents a single completed run.
///
/// This is the central data shape for the whole app — the feed, the
/// profile stats, the tracking screen, and (from Week 3 onward) the
/// backend API will all pass this same object around.
class Activity {
  final String id;
  final String title;
  final DateTime date;
  final double distanceKm;
  final Duration duration;
  final int? averageHeartRate; // nullable: not every run has HR data
  final double elevationGainM;
  final List<LatLng> route; // the recorded GPS path
 
  Activity({
    required this.id,
    required this.title,
    required this.date,
    required this.distanceKm,
    required this.duration,
    required this.elevationGainM,
    required this.route,
    this.averageHeartRate,
  });
 
  /// Average pace in minutes per kilometer.
  /// Guarded against distanceKm == 0 to avoid division-by-zero (e.g. a
  /// run that failed to record GPS data).
  double get paceMinPerKm {
    if (distanceKm <= 0) return 0;
    return duration.inSeconds / 60 / distanceKm;
  }
 
  /// Formats pace as "5:12 /km" instead of a raw decimal — this is what
  /// you'll actually display in the UI.
  String get formattedPace {
    if (distanceKm <= 0) return '--:-- /km';
    final totalSeconds = (paceMinPerKm * 60).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }
 
  /// Formats duration as "1h 04m" or "42m" for display in cards.
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes}m';
  }
 
  /// Converts this object into a plain Map, which becomes JSON when sent
  /// to the FastAPI backend (Week 3). Route points are flattened into
  /// simple {lat, lng} maps since JSON has no concept of a LatLng object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'distance_km': distanceKm,
      'duration_seconds': duration.inSeconds,
      'average_heart_rate': averageHeartRate,
      'elevation_gain_m': elevationGainM,
      'route': route
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
    };
  }
 
  /// Rebuilds an Activity from JSON received from the backend.
  /// This is the reverse of toJson() — you'll use this once Week 3's
  /// API calls start returning real data.
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      distanceKm: (json['distance_km'] as num).toDouble(),
      duration: Duration(seconds: json['duration_seconds'] as int),
      averageHeartRate: json['average_heart_rate'] as int?,
      elevationGainM: (json['elevation_gain_m'] as num).toDouble(),
      route: (json['route'] as List)
          .map((p) => LatLng(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble(),
              ))
          .toList(),
    );
  }
}
 