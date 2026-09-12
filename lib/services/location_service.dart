import 'package:geolocator/geolocator.dart';
 
/// Everything that touches raw GPS APIs lives here and nowhere else.
/// The tracking provider and screen only ever talk to this interface —
/// they never import `geolocator` directly. That's what makes it safe
/// to swap in [MockLocationService] on an emulator with no real GPS,
/// or later swap the whole package, without touching any UI code.
abstract class LocationService {
  /// Confirms location services are on and permission is granted.
  /// Throws a [LocationServiceException] with a message safe to show
  /// directly in the UI — callers should never see a raw platform
  /// exception here.
  Future<void> ensureReady();
 
  /// A live stream of device positions. Any platform-level failure
  /// (permission revoked mid-stream, GPS lost) arrives as a
  /// [LocationServiceException], never a raw platform error.
  Stream<Position> positionStream();
}
 
class LocationServiceException implements Exception {
  const LocationServiceException(this.message);
  final String message;
 
  @override
  String toString() => message;
}
 
/// Real implementation, backed by the `geolocator` package.
class GeolocatorLocationService implements LocationService {
  @override
  Future<void> ensureReady() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationServiceException(
          'Turn on location services to record an activity.',
        );
      }
 
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw const LocationServiceException(
            'STRIDE needs location access to track your activity.',
          );
        }
      }
 
      if (permission == LocationPermission.deniedForever) {
        throw const LocationServiceException(
          'Location access is permanently denied for STRIDE. '
          'Enable it in system settings to record activities.',
        );
      }
    } on LocationServiceException {
      rethrow; // our own deliberate errors — pass through unchanged
    } catch (e) {
      // Anything unexpected from the platform gets the same clean shape,
      // so nothing above this file ever has to handle a raw platform
      // exception type.
      throw LocationServiceException('Could not access location: $e');
    }
  }
 
  @override
  Stream<Position> positionStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5, // meters — ignores GPS jitter under 5m
    );
 
    return Geolocator.getPositionStream(locationSettings: settings)
        .handleError((Object error, StackTrace stackTrace) {
      // Converts a mid-stream platform failure (e.g. permission revoked
      // while actively recording) into our own exception type, instead
      // of a raw platform error reaching the tracking provider.
      throw LocationServiceException('Lost location access: $error');
    });
  }
}
 
/// Simulated GPS for building/testing the tracking screen on an
/// emulator, where there's no real hardware GPS to move around with.
class MockLocationService implements LocationService {
  MockLocationService({this.tickInterval = const Duration(seconds: 2)});
 
  final Duration tickInterval;
 
  @override
  Future<void> ensureReady() async {
    // No real permissions to check for a simulated stream.
  }
 
  @override
  Stream<Position> positionStream() async* {
    // Walks a fixed path north-east from a placeholder start point —
    // swap these coordinates for wherever you're testing.
    var lat = 12.9716;
    var lng = 77.5946;
 
    while (true) {
      await Future.delayed(tickInterval);
      lat += 0.00006;
      lng += 0.00004;
      yield Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 480,
        altitudeAccuracy: 5,
        heading: 45,
        headingAccuracy: 5,
        speed: 2.7, // ~ easy jog pace, meters/second
        speedAccuracy: 0.5,
        floor: null,
        isMocked: true, // honest labeling — this is simulated, not real GPS
      );
    }
  }
}
 