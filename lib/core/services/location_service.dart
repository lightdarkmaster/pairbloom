import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationFailure { serviceOff, denied, deniedForever, timeout, unknown }

class LocationException implements Exception {
  LocationException(this.reason);
  final LocationFailure reason;

  String get message => switch (reason) {
        LocationFailure.serviceOff => 'Location services are off. Turn them on and try again.',
        LocationFailure.denied => 'Location permission was denied.',
        LocationFailure.deniedForever => 'Location permission is blocked. Enable it in app settings.',
        LocationFailure.timeout => 'Could not get a GPS fix. Try outdoors or near a window.',
        LocationFailure.unknown => 'Could not read your location.',
      };
  @override
  String toString() => message;
}

class LocationFix {
  LocationFix(this.latitude, this.longitude, this.accuracyM);
  final double latitude, longitude, accuracyM;
}

/// One-time GPS reading. GPS works without internet; PairBloom never tracks you
/// in the background and only reads your position when you tap the button.
class LocationService {
  Future<LocationFix> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException(LocationFailure.serviceOff);
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) throw LocationException(LocationFailure.denied);
    if (perm == LocationPermission.deniedForever) throw LocationException(LocationFailure.deniedForever);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)),
      );
      return LocationFix(pos.latitude, pos.longitude, pos.accuracy);
    } on TimeoutException {
      throw LocationException(LocationFailure.timeout);
    } catch (_) {
      throw LocationException(LocationFailure.unknown);
    }
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
