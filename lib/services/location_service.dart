import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Location service for staff geofenced check-in
class LocationService {
  /// Earth radius in kilometers for Haversine formula
  static const double earthRadiusKm = 6371;

  /// Request location permission from the user
  static Future<LocationPermission> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermission.denied;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermission.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermission.deniedForever;
    }

    return permission;
  }
  
  /// Request background location permission (needed for auto clock-out)
  static Future<bool> requestBackgroundLocationPermission() async {
    // First ensure we have basic location permission
    final basicPermission = await requestLocationPermission();
    if (basicPermission == LocationPermission.denied ||
        basicPermission == LocationPermission.deniedForever) {
      return false;
    }
    
    // Check if we already have "always" permission
    if (basicPermission == LocationPermission.always) {
      return true;
    }
    
    // On Android, we need to explicitly request background location
    if (Platform.isAndroid) {
      // Use permission_handler for background location on Android
      final status = await Permission.locationAlways.request();
      return status.isGranted;
    }
    
    // On iOS, requestPermission already handles always permission
    // The system will show the appropriate dialog
    final alwaysPermission = await Geolocator.requestPermission();
    return alwaysPermission == LocationPermission.always;
  }
  
  /// Check if background location permission is granted
  static Future<bool> hasBackgroundLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Get current location with high accuracy
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled first
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      final permission = await requestLocationPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Location permission denied or denied forever');
        return null;
      }

      // Try to get current position with reasonable timeout
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 30),
          ),
        );
      } catch (e) {
        print('High accuracy location failed: $e');
        // If high accuracy fails, try with medium accuracy as fallback
        try {
          return await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 20),
            ),
          );
        } catch (e2) {
          print('Fallback location also failed: $e2');
          return null;
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Calculate distance between two GPS coordinates using Haversine formula
  /// Returns distance in meters
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c * 1000; // Convert to meters
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Check if a position is within a radius of a target location
  static bool isWithinRadius(
    double currentLat,
    double currentLon,
    double targetLat,
    double targetLon,
    double radiusMeters,
  ) {
    final distance = calculateDistance(
      currentLat,
      currentLon,
      targetLat,
      targetLon,
    );
    return distance <= radiusMeters;
  }

  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Open app settings for location permission
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open location settings
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
  
  /// Get a stream of position updates for background tracking
  /// This continues to work when the app is in the background
  static Stream<Position> getPositionStream({
    int distanceFilter = 50, // Minimum distance (in meters) before an update is triggered
    int intervalDuration = 60000, // Time between updates in milliseconds (default 1 minute)
  }) {
    late LocationSettings locationSettings;
    
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        intervalDuration: Duration(milliseconds: intervalDuration),
        // Enable foreground notification for background tracking
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'BMS Pro Pink is monitoring your location for auto clock-out',
          notificationTitle: 'Location Tracking Active',
          enableWakeLock: true,
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        ),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.other,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      );
    }
    
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}

/// Location validation result
class LocationValidationResult {
  final bool isWithinRadius;
  final double distanceMeters;
  final String message;

  LocationValidationResult({
    required this.isWithinRadius,
    required this.distanceMeters,
    required this.message,
  });
}
