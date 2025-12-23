import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';

class AppColors {
  static const primary = Color(0xFFFF2D8F);
  static const primaryDark = Color(0xFFD81F75);
  static const accent = Color(0xFFFF6FB5);
  static const background = Color(0xFFFFF5FA);
  static const card = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF9E9E9E);
  static const border = Color(0xFFF2D2E9);
}

/// Radius options for check-in
const List<Map<String, dynamic>> radiusOptions = [
  {'value': 50, 'label': '50m (Strict)'},
  {'value': 100, 'label': '100m (Default)'},
  {'value': 150, 'label': '150m'},
  {'value': 200, 'label': '200m'},
  {'value': 300, 'label': '300m'},
  {'value': 500, 'label': '500m (Relaxed)'},
];

/// Branch location data
class BranchLocationData {
  final double latitude;
  final double longitude;
  final String? formattedAddress;
  final int allowedRadius;

  BranchLocationData({
    required this.latitude,
    required this.longitude,
    this.formattedAddress,
    required this.allowedRadius,
  });
}

/// Page for selecting/editing branch location with Google Maps
class BranchLocationPickerPage extends StatefulWidget {
  final String branchId;
  final String branchName;
  final double? initialLatitude;
  final double? initialLongitude;
  final int initialRadius;

  const BranchLocationPickerPage({
    super.key,
    required this.branchId,
    required this.branchName,
    this.initialLatitude,
    this.initialLongitude,
    this.initialRadius = 100,
  });

  @override
  State<BranchLocationPickerPage> createState() => _BranchLocationPickerPageState();
}

class _BranchLocationPickerPageState extends State<BranchLocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  int _selectedRadius = 100;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isGettingCurrentLocation = false;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _selectedRadius = widget.initialRadius;
    
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _updateMarkerAndCircle();
    }
  }

  void _updateMarkerAndCircle() {
    if (_selectedLocation == null) {
      setState(() {
        _markers = {};
        _circles = {};
      });
      return;
    }

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('branch_location'),
          position: _selectedLocation!,
          draggable: true,
          onDragEnd: (newPosition) {
            _onLocationSelected(newPosition);
          },
          infoWindow: InfoWindow(
            title: widget.branchName,
            snippet: 'Drag to adjust location',
          ),
        ),
      };

      _circles = {
        Circle(
          circleId: const CircleId('check_in_radius'),
          center: _selectedLocation!,
          radius: _selectedRadius.toDouble(),
          strokeWidth: 2,
          strokeColor: AppColors.primary,
          fillColor: AppColors.primary.withOpacity(0.15),
        ),
      };
    });
  }

  void _onLocationSelected(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
    _updateMarkerAndCircle();
    
    // Animate to the new location
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 17),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingCurrentLocation = true);

    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        final latLng = LatLng(position.latitude, position.longitude);
        _onLocationSelected(latLng);
        _showSnackBar('Location captured successfully');
      } else {
        _showSnackBar('Could not get your location', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error getting location: $e', isError: true);
    } finally {
      setState(() => _isGettingCurrentLocation = false);
    }
  }

  Future<void> _saveLocation() async {
    if (_selectedLocation == null) {
      _showSnackBar('Please select a location first', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .update({
        'location': {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
        },
        'allowedCheckInRadius': _selectedRadius,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Branch location saved successfully');
      
      // Return the new location data
      Navigator.pop(context, BranchLocationData(
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        allowedRadius: _selectedRadius,
      ));
    } catch (e) {
      _showSnackBar('Failed to save location: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? FontAwesomeIcons.circleExclamation : FontAwesomeIcons.circleCheck,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Default center (Sydney) if no initial location
    final initialCenter = widget.initialLatitude != null && widget.initialLongitude != null
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : const LatLng(-33.8688, 151.2093);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft, size: 18, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Branch Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            Text(
              widget.branchName,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _isSaving ? null : _saveLocation,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialCenter,
              zoom: widget.initialLatitude != null ? 17 : 12,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_selectedLocation != null) {
                _updateMarkerAndCircle();
              }
            },
            onTap: _onLocationSelected,
            markers: _markers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Instructions Banner
          if (_selectedLocation == null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(FontAwesomeIcons.locationDot, color: AppColors.primary, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tap on the map to set your branch location, or use the button below to use your current location.',
                        style: TextStyle(fontSize: 13, color: AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Current Location Button
          Positioned(
            bottom: 200,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'current_location',
              onPressed: _isGettingCurrentLocation ? null : _getCurrentLocation,
              backgroundColor: Colors.white,
              child: _isGettingCurrentLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(FontAwesomeIcons.crosshairs, color: AppColors.primary),
            ),
          ),

          // Bottom Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location Info
                      if (_selectedLocation != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(FontAwesomeIcons.locationDot, color: Colors.green.shade700, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Location Selected',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Radius Selector
                      const Text(
                        'Check-in Radius',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Staff must be within this distance to check in',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: radiusOptions.map((option) {
                          final isSelected = _selectedRadius == option['value'];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRadius = option['value'];
                              });
                              _updateMarkerAndCircle();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                option['label'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : AppColors.text,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: (_selectedLocation == null || _isSaving) ? null : _saveLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Saving...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(FontAwesomeIcons.floppyDisk, size: 16),
                                    SizedBox(width: 12),
                                    Text('Save Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
