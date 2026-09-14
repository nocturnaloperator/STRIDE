import 'package:geolocator/geolocator.dart';

/// Everything that touches raw GPS APIs lives here.
///
/// The tracking provider and UI never need to know how Android/iOS
/// permissions or GPS access actually work.
abstract class LocationService {
  /// Checks that location services are enabled and that STRIDE
  /// has the required location permission.
  ///
  /// Requests permission when Android has not decided yet.
  /// Throws a LocationServiceException when tracking cannot start.
  Future<void> ensureReady();

  /// Returns a live stream of device GPS positions.
  Stream<Position> positionStream();
}

/// Application-level location error.
class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Real GPS implementation using Geolocator.
class GeolocatorLocationService implements LocationService {
  @override
  Future<void> ensureReady() async {
    try {
      // ------------------------------------------------------------
      // 1. Check whether the phone's location/GPS service is enabled.
      // ------------------------------------------------------------
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw const LocationServiceException(
          'Location services are turned off. '
          'Turn on GPS/location and try again.',
        );
      }

      // ------------------------------------------------------------
      // 2. Check STRIDE's current location permission.
      // ------------------------------------------------------------
      var permission = await Geolocator.checkPermission();

      // ------------------------------------------------------------
      // 3. Permission has not been granted yet.
      //
      // This is the important part:
      // requestPermission() triggers Android's location permission
      // dialog when the OS allows the app to request it.
      // ------------------------------------------------------------
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // ------------------------------------------------------------
      // 4. User denied the permission.
      // ------------------------------------------------------------
      if (permission == LocationPermission.denied) {
        throw const LocationServiceException(
          'STRIDE needs location permission to record your run.',
        );
      }

      // ------------------------------------------------------------
      // 5. User permanently denied the permission.
      //
      // Android will normally require the user to enable it manually
      // from the app's settings.
      // ------------------------------------------------------------
      if (permission == LocationPermission.deniedForever) {
        throw const LocationServiceException(
          'Location permission is permanently denied for STRIDE. '
          'Open Settings → Apps → STRIDE → Permissions → Location '
          'and allow location access.',
        );
      }

      // ------------------------------------------------------------
      // 6. Permission is granted.
      //
      // The method returns and the tracking provider can safely start
      // listening to the GPS stream.
      // ------------------------------------------------------------
    } on LocationServiceException {
      rethrow;
    } catch (error) {
      throw LocationServiceException(
        'Could not access location: $error',
      );
    }
  }

  @override
  Stream<Position> positionStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );

    return Geolocator.getPositionStream(
      locationSettings: settings,
    ).handleError(
      (Object error, StackTrace stackTrace) {
        throw LocationServiceException(
          'Lost location access: $error',
        );
      },
    );
  }
}

/// Simulated GPS implementation for emulator/testing.
///
/// STRIDE does NOT use this on your real phone because the provider
/// is currently configured to use GeolocatorLocationService().
class MockLocationService implements LocationService {
  MockLocationService({
    this.tickInterval = const Duration(seconds: 2),
  });

  final Duration tickInterval;

  @override
  Future<void> ensureReady() async {
    // Mock GPS does not need Android location permission.
  }

  @override
  Stream<Position> positionStream() async* {
    var latitude = 12.9716;
    var longitude = 77.5946;

    while (true) {
      await Future.delayed(tickInterval);

      latitude += 0.00006;
      longitude += 0.00004;

      yield Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 480,
        altitudeAccuracy: 5,
        heading: 45,
        headingAccuracy: 5,
        speed: 2.7,
        speedAccuracy: 0.5,
        floor: null,
        isMocked: true,
      );
    }
  }
}