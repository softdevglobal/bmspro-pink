import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling app permissions (location, notifications, etc.)
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request all required permissions at app startup
  /// This includes notification and location permissions
  Future<void> requestAllPermissions() async {
    debugPrint('📋 Requesting app permissions...');
    
    // Request notification permission (handled by NotificationService)
    // Location permission
    await requestLocationPermission();
    
    debugPrint('✅ Permission requests completed');
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    try {
      debugPrint('📍 Requesting location permission...');
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ Location services are disabled');
        // Don't return false - we can still request permission
        // The system will prompt to enable location services when needed
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 Current location permission: $permission');
      
      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        debugPrint('📍 Permission after request: $permission');
        
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission permanently denied');
        return false;
      }

      debugPrint('✅ Location permission granted: $permission');
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting location permission: $e');
      return false;
    }
  }

  /// Request background location permission (needed for auto clock-out feature)
  Future<bool> requestBackgroundLocationPermission() async {
    try {
      debugPrint('📍 Requesting background location permission...');
      
      // First ensure we have basic location permission
      final hasBasicPermission = await requestLocationPermission();
      if (!hasBasicPermission) {
        return false;
      }
      
      // Check if we already have "always" permission
      final currentPermission = await Geolocator.checkPermission();
      if (currentPermission == LocationPermission.always) {
        debugPrint('✅ Background location permission already granted');
        return true;
      }
      
      // On Android, we need to explicitly request background location
      if (Platform.isAndroid) {
        // Use permission_handler for background location on Android
        final status = await Permission.locationAlways.request();
        debugPrint('📍 Android background permission status: $status');
        return status.isGranted;
      }
      
      // On iOS, requestPermission handles "always" permission
      // The system will show the appropriate dialog
      final alwaysPermission = await Geolocator.requestPermission();
      debugPrint('📍 iOS background permission: $alwaysPermission');
      return alwaysPermission == LocationPermission.always;
    } catch (e) {
      debugPrint('❌ Error requesting background location permission: $e');
      return false;
    }
  }

  /// Check if location permission is granted
  Future<bool> isLocationPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Check if background location permission is granted
  Future<bool> isBackgroundLocationPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Show permission rationale dialog for location
  static Future<bool> showLocationPermissionRationale(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D8F).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFFFF2D8F),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Location Permission'),
          ],
        ),
        content: const Text(
          'BMS Pro Pink needs access to your location for:\n\n'
          '• Staff check-in at salon locations\n'
          '• Auto clock-out when you leave the salon\n'
          '• Verifying your presence at the workplace\n\n'
          'Please allow location access for the best experience.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2D8F),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show dialog when permission is permanently denied
  static Future<void> showPermissionDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Permission Required'),
          ],
        ),
        content: const Text(
          'Location permission is required for staff check-in features.\n\n'
          'Please go to Settings and enable location permission for BMS Pro Pink.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2D8F),
            ),
            onPressed: () {
              Navigator.pop(context);
              PermissionService().openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

