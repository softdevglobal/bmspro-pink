import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_service.dart';
import 'staff_check_in_service.dart';

/// Service for background location tracking and auto clock-out
/// This service monitors the user's location even when the app is in the background
/// and automatically clocks them out if they exceed the branch radius
class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();
  
  StreamSubscription<Position>? _positionSubscription;
  Timer? _periodicCheckTimer;
  String? _activeCheckInId;
  String? _activeBranchId;
  double? _branchLatitude;
  double? _branchLongitude;
  double? _allowedRadius;
  bool _isMonitoring = false;
  bool _isCheckingLocation = false; // Prevent concurrent checks
  
  // Callbacks
  Function(String message)? onAutoCheckOut;
  Function(double distance, double allowedRadius)? onDistanceUpdate;
  
  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;
  
  /// Get active check-in ID
  String? get activeCheckInId => _activeCheckInId;
  
  /// Start monitoring location for auto clock-out
  /// Call this when the user checks in
  Future<bool> startMonitoring({
    required String checkInId,
    required String branchId,
    required double branchLatitude,
    required double branchLongitude,
    required double allowedRadius,
  }) async {
    // Stop any existing monitoring first
    await stopMonitoring();
    
    // Check for location permission (at least while in use)
    final hasBasicPermission = await LocationService.isLocationPermissionGranted();
    if (!hasBasicPermission) {
      debugPrint('BackgroundLocationService: No location permission');
      final permission = await LocationService.requestLocationPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        debugPrint('BackgroundLocationService: Failed to get location permission');
        return false;
      }
    }
    
    // Try to get background permission (optional, but preferred)
    final hasBackgroundPermission = await LocationService.hasBackgroundLocationPermission();
    if (!hasBackgroundPermission) {
      debugPrint('BackgroundLocationService: No background location permission, requesting...');
      await LocationService.requestBackgroundLocationPermission();
      // Continue even if background permission is not granted
      // The foreground monitoring will still work
    }
    
    _activeCheckInId = checkInId;
    _activeBranchId = branchId;
    _branchLatitude = branchLatitude;
    _branchLongitude = branchLongitude;
    _allowedRadius = allowedRadius;
    
    try {
      // Start listening to position stream for movement-based updates
      _positionSubscription = LocationService.getPositionStream(
        distanceFilter: 20, // Update every 20 meters movement
        intervalDuration: 30000, // Check every 30 seconds minimum
      ).listen(
        _onPositionUpdate,
        onError: _onPositionError,
        cancelOnError: false,
      );
      
      // Start periodic timer for regular checks (every 2 minutes)
      // This ensures checks happen even when user is not moving
      _startPeriodicCheck();
      
      _isMonitoring = true;
      debugPrint('BackgroundLocationService: Started monitoring for check-in $checkInId');
      
      // Perform immediate location check
      await _performImmediateLocationCheck();
      
      return true;
    } catch (e) {
      debugPrint('BackgroundLocationService: Error starting monitoring: $e');
      return false;
    }
  }
  
  /// Start periodic timer for regular location checks
  void _startPeriodicCheck() {
    _periodicCheckTimer?.cancel();
    // Check every 2 minutes to catch out-of-radius cases when user is not moving
    _periodicCheckTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _performImmediateLocationCheck();
    });
    debugPrint('BackgroundLocationService: Started periodic check timer (every 2 min)');
  }
  
  /// Perform an immediate location check
  Future<void> _performImmediateLocationCheck() async {
    if (_activeCheckInId == null ||
        _branchLatitude == null ||
        _branchLongitude == null ||
        _allowedRadius == null) {
      return;
    }
    
    // Prevent concurrent checks
    if (_isCheckingLocation) {
      debugPrint('BackgroundLocationService: Already checking location, skipping...');
      return;
    }
    
    _isCheckingLocation = true;
    
    try {
      debugPrint('BackgroundLocationService: Performing immediate location check...');
      
      final position = await LocationService.getCurrentLocation();
      if (position == null) {
        debugPrint('BackgroundLocationService: Could not get current location');
        return;
      }
      
      // Calculate distance from branch
      final distance = LocationService.calculateDistance(
        position.latitude,
        position.longitude,
        _branchLatitude!,
        _branchLongitude!,
      );
      
      debugPrint('BackgroundLocationService: Immediate check - Distance: ${distance.toStringAsFixed(1)}m, allowed: ${_allowedRadius!.toStringAsFixed(1)}m');
      
      // Notify about distance update
      onDistanceUpdate?.call(distance, _allowedRadius!);
      
      // Check if outside radius
      if (distance > _allowedRadius!) {
        debugPrint('BackgroundLocationService: Outside radius! Auto clock-out triggered (immediate check)');
        await _performAutoCheckOut(position, distance);
      }
    } catch (e) {
      debugPrint('BackgroundLocationService: Error in immediate location check: $e');
    } finally {
      _isCheckingLocation = false;
    }
  }
  
  /// Stop monitoring location
  Future<void> stopMonitoring() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
    _activeCheckInId = null;
    _activeBranchId = null;
    _branchLatitude = null;
    _branchLongitude = null;
    _allowedRadius = null;
    _isMonitoring = false;
    _isCheckingLocation = false;
    debugPrint('BackgroundLocationService: Stopped monitoring');
  }
  
  /// Handle position updates
  void _onPositionUpdate(Position position) async {
    if (_activeCheckInId == null ||
        _branchLatitude == null ||
        _branchLongitude == null ||
        _allowedRadius == null) {
      return;
    }
    
    // Calculate distance from branch
    final distance = LocationService.calculateDistance(
      position.latitude,
      position.longitude,
      _branchLatitude!,
      _branchLongitude!,
    );
    
    debugPrint('BackgroundLocationService: Distance from branch: ${distance.toStringAsFixed(1)}m, allowed: ${_allowedRadius!.toStringAsFixed(1)}m');
    
    // Notify about distance update
    onDistanceUpdate?.call(distance, _allowedRadius!);
    
    // Check if outside radius
    if (distance > _allowedRadius!) {
      debugPrint('BackgroundLocationService: Outside radius! Auto clock-out triggered');
      await _performAutoCheckOut(position, distance);
    }
  }
  
  /// Handle position stream errors
  void _onPositionError(dynamic error) {
    debugPrint('BackgroundLocationService: Position stream error: $error');
    // Don't stop monitoring on error, let it retry
  }
  
  /// Perform auto check-out
  Future<void> _performAutoCheckOut(Position position, double distance) async {
    if (_activeCheckInId == null) return;
    
    final checkInId = _activeCheckInId!;
    
    try {
      // Use the existing auto check-out method
      final wasCheckedOut = await StaffCheckInService.autoCheckOutIfExceededRadius(
        checkInId: checkInId,
        currentLatitude: position.latitude,
        currentLongitude: position.longitude,
      );
      
      if (wasCheckedOut) {
        debugPrint('BackgroundLocationService: Auto check-out successful');
        
        // Create a notification in Firestore for the user
        await _createAutoCheckOutNotification(distance);
        
        // Notify callback
        onAutoCheckOut?.call(
          'You have been automatically clocked out because you exceeded the branch radius (${distance.toStringAsFixed(0)}m away)',
        );
        
        // Stop monitoring since user is checked out
        await stopMonitoring();
      }
    } catch (e) {
      debugPrint('BackgroundLocationService: Error during auto check-out: $e');
    }
  }
  
  /// Create a notification for the auto check-out
  Future<void> _createAutoCheckOutNotification(double distance) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Get branch name
      String branchName = 'Unknown Branch';
      if (_activeBranchId != null) {
        final branchDoc = await FirebaseFirestore.instance
            .collection('branches')
            .doc(_activeBranchId)
            .get();
        if (branchDoc.exists) {
          branchName = branchDoc.data()?['name'] ?? 'Unknown Branch';
        }
      }
      
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'auto_clock_out',
        'title': 'Auto Clock-Out',
        'message': 'You were automatically clocked out from $branchName because you exceeded the branch radius (${distance.toStringAsFixed(0)}m away).',
        'staffUid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'data': {
          'checkInId': _activeCheckInId,
          'branchId': _activeBranchId,
          'distance': distance,
        },
      });
    } catch (e) {
      debugPrint('BackgroundLocationService: Error creating notification: $e');
    }
  }
  
  /// Resume monitoring for an active check-in
  /// Call this when the app starts to check if there's an active check-in that needs monitoring
  Future<void> resumeMonitoringIfNeeded() async {
    try {
      debugPrint('BackgroundLocationService: Checking for active check-in to resume monitoring...');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('BackgroundLocationService: No authenticated user');
        return;
      }
      
      final activeCheckIn = await StaffCheckInService.getActiveCheckIn();
      if (activeCheckIn == null) {
        debugPrint('BackgroundLocationService: No active check-in to monitor');
        // Make sure monitoring is stopped if no active check-in
        await stopMonitoring();
        return;
      }
      
      debugPrint('BackgroundLocationService: Found active check-in: ${activeCheckIn.id}');
      
      // Get branch details
      final branchDoc = await FirebaseFirestore.instance
          .collection('branches')
          .doc(activeCheckIn.branchId)
          .get();
      
      if (!branchDoc.exists) {
        debugPrint('BackgroundLocationService: Branch not found');
        return;
      }
      
      final branchData = branchDoc.data()!;
      final location = branchData['location'] as Map<String, dynamic>?;
      
      if (location == null ||
          location['latitude'] == null ||
          location['longitude'] == null) {
        debugPrint('BackgroundLocationService: Branch location not found');
        return;
      }
      
      final branchLat = (location['latitude'] as num).toDouble();
      final branchLon = (location['longitude'] as num).toDouble();
      final allowedRadius = (branchData['allowedCheckInRadius'] ?? 100).toDouble();
      
      // Check if activeCheckIn has a valid id
      final checkInId = activeCheckIn.id;
      if (checkInId == null) {
        debugPrint('BackgroundLocationService: Check-in ID is null');
        return;
      }
      
      // If already monitoring this check-in, just perform an immediate check
      if (_isMonitoring && _activeCheckInId == checkInId) {
        debugPrint('BackgroundLocationService: Already monitoring this check-in, performing immediate check');
        await _performImmediateLocationCheck();
        return;
      }
      
      // Start monitoring (this will perform an immediate check)
      final success = await startMonitoring(
        checkInId: checkInId,
        branchId: activeCheckIn.branchId,
        branchLatitude: branchLat,
        branchLongitude: branchLon,
        allowedRadius: allowedRadius,
      );
      
      if (success) {
        debugPrint('BackgroundLocationService: Resumed monitoring for check-in $checkInId');
      } else {
        debugPrint('BackgroundLocationService: Failed to resume monitoring');
      }
    } catch (e) {
      debugPrint('BackgroundLocationService: Error resuming monitoring: $e');
    }
  }
  
  /// Check location immediately and auto clock-out if needed
  /// This is a public method that can be called from anywhere
  Future<void> checkLocationNow() async {
    if (!_isMonitoring) {
      // Try to resume monitoring first
      await resumeMonitoringIfNeeded();
    } else {
      await _performImmediateLocationCheck();
    }
  }
}

