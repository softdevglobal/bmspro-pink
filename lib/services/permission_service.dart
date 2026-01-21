import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling app permissions (location, notifications, etc.)
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();
  
  /// Track if background location disclosure has been shown
  static bool _backgroundLocationDisclosureShown = false;

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
  /// Note: This requires showing a prominent disclosure first on Android
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
  
  /// Request background location permission WITH prominent disclosure dialog
  /// This method should be used instead of requestBackgroundLocationPermission()
  /// to comply with Google Play's Prominent Disclosure and Consent Requirement
  Future<bool> requestBackgroundLocationWithDisclosure(BuildContext context) async {
    try {
      debugPrint('📍 Requesting background location with disclosure...');
      
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
      
      // Show prominent disclosure dialog BEFORE requesting permission
      // This is required by Google Play policy
      final userConsent = await showBackgroundLocationDisclosure(context);
      if (!userConsent) {
        debugPrint('❌ User declined background location disclosure');
        return false;
      }
      
      // Mark disclosure as shown
      _backgroundLocationDisclosureShown = true;
      
      // Now request the actual permission
      if (Platform.isAndroid) {
        final status = await Permission.locationAlways.request();
        debugPrint('📍 Android background permission status: $status');
        return status.isGranted;
      }
      
      // On iOS
      final alwaysPermission = await Geolocator.requestPermission();
      debugPrint('📍 iOS background permission: $alwaysPermission');
      return alwaysPermission == LocationPermission.always;
    } catch (e) {
      debugPrint('❌ Error requesting background location with disclosure: $e');
      return false;
    }
  }
  
  /// Check if background location disclosure has been shown
  static bool get hasShownBackgroundLocationDisclosure => _backgroundLocationDisclosureShown;
  
  /// Show the prominent disclosure dialog for background location
  /// Required by Google Play policy for BACKGROUND_LOCATION permission
  static Future<bool> showBackgroundLocationDisclosure(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D8F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFFFF2D8F),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              const Text(
                'Background Location Access',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Disclosure text - REQUIRED by Google Play policy
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF2D8F).withOpacity(0.2),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This app collects location data to enable automatic clock-out when you leave your workplace, even when the app is closed or not in use.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Why we need this:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 8),
                    _DisclosureItem(
                      icon: Icons.timer_outlined,
                      text: 'Automatic clock-out when you leave the salon',
                    ),
                    SizedBox(height: 6),
                    _DisclosureItem(
                      icon: Icons.verified_outlined,
                      text: 'Accurate timesheet tracking',
                    ),
                    SizedBox(height: 6),
                    _DisclosureItem(
                      icon: Icons.security_outlined,
                      text: 'Prevent accidental unpaid overtime',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Privacy note
              const Text(
                'Your location data is only used for staff attendance purposes and is never shared with third parties.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9E9E9E),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF9E9E9E)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Not Now',
                        style: TextStyle(color: Color(0xFF9E9E9E)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D8F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'I Understand',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
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

/// Helper widget for disclosure items
class _DisclosureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  
  const _DisclosureItem({
    required this.icon,
    required this.text,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFFFF2D8F),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }
}

