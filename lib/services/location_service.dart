import 'package:geolocator/geolocator.dart';

abstract class LocationService {
  Future<void> ensureReady();

  Future<Position?> lastKnownPosition();

  Future<Position> currentPosition();

  Stream<Position> positionStream();
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<void> ensureReady() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Location services are turned off. '
        'Turn on GPS/location and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException(
        'STRIDE needs location permission to show your location.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission is permanently denied for STRIDE. '
        'Open Settings → Apps → STRIDE → Permissions → Location '
        'and allow location access.',
      );
    }
  }

  @override
  Future<Position?> lastKnownPosition() async {
    try {
      final position =
          await Geolocator.getLastKnownPosition();

      if (position == null) {
        return null;
      }

      if (!position.accuracy.isFinite ||
          position.accuracy > 30) {
        return null;
      }

      return position;
    } catch (error) {
      throw LocationServiceException(
        'Could not read your last known location: $error',
      );
    }
  }

  @override
  Future<Position> currentPosition() async {
    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.best,
      );

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      if (!position.accuracy.isFinite ||
          position.accuracy > 30) {
        throw const LocationServiceException(
          'GPS accuracy is currently too low. '
          'Move to an area with a clearer GPS signal and try again.',
        );
      }

      return position;
    } catch (error) {
      if (error is LocationServiceException) {
        rethrow;
      }

      throw LocationServiceException(
        'Could not get your current location: $error',
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
    ).where(
      (position) =>
          position.accuracy.isFinite &&
          position.accuracy <= 30,
    );
  }
}