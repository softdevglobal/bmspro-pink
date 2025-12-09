import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- 1. Theme & Colors (Matching HTML/Tailwind) ---
class AppColors {
  static const primary = Color(0xFFFF2D8F);
  static const accent = Color(0xFFFF6FB5);
  static const background = Color(0xFFFFF5FA);
  static const card = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF9E9E9E);
  static const border = Color(0xFFF2D2E9);
  static const green = Color(0xFF10B981);
  static const purple = Color(0xFF9333EA); // Purple-600
  static const blue = Color(0xFF2563EB); // Blue-600
}

class WalkInBookingPage extends StatefulWidget {
  const WalkInBookingPage({super.key});

  @override
  State<WalkInBookingPage> createState() => _WalkInBookingPageState();
}

class _WalkInBookingPageState extends State<WalkInBookingPage> with TickerProviderStateMixin {
  // State Variables
  int _currentStep = 0; // 0: Branch & Services, 1: Date & Staff, 2: Details

  // Step 1 – branch & services
  String? _selectedBranchLabel;
  Set<String> _selectedServiceIds = {}; // multiple services supported

  // Step 2 – date & per-service time/staff
  DateTime? _selectedDate;
  Map<String, TimeOfDay> _serviceTimeSelections = {}; // serviceId -> time
  Map<String, String> _serviceStaffSelections = {}; // serviceId -> staffId ('any' or actual ID)

  bool _isProcessing = false;

  // Auth / owner context
  String? _ownerUid;
  String? _userRole;
  String? _userBranchId;
  bool _loadingContext = true;
  String? _selectedBranchId;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Live data from Firestore (mirroring admin panel sources)
  List<Map<String, dynamic>> _branches = []; // {id, name, address}
  List<Map<String, dynamic>> _services = []; // {id, name, price, duration, branches, staffIds}
  List<Map<String, dynamic>> _staff = []; // {id, name, status, avatar, branchId}
  bool _loadingData = true;
  String? _dataError;

  @override
  void initState() {
    super.initState();
    // Fade Animation
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _loadUserContext();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // --- Logic Helpers ---
  int get _totalPrice {
    int total = 0;
    for (final serviceId in _selectedServiceIds) {
      final service = _services.firstWhere((s) => s['id'] == serviceId, orElse: () => {});
      if (service.isNotEmpty) {
        total += (service['price'] as num).toInt();
      }
    }
    return total;
  }

  int get _totalDuration {
    int total = 0;
    for (final serviceId in _selectedServiceIds) {
      final service = _services.firstWhere((s) => s['id'] == serviceId, orElse: () => {});
      if (service.isNotEmpty && service['duration'] != null) {
        total += (service['duration'] as num).toInt();
      }
    }
    return total;
  }

  void _selectService(String id) {
    debugPrint('[SelectService] Tapped service id: $id');
    debugPrint('[SelectService] Before: $_selectedServiceIds');
    setState(() {
      // Create a new Set to ensure Flutter detects the change
      final newSet = Set<String>.from(_selectedServiceIds);
      if (newSet.contains(id)) {
        newSet.remove(id); // Deselect
        debugPrint('[SelectService] Removed $id');
      } else {
        newSet.add(id); // Add to selection
        debugPrint('[SelectService] Added $id');
      }
      _selectedServiceIds = newSet;
      debugPrint('[SelectService] After: $_selectedServiceIds');
    });
  }

  void _confirmBooking() {
    if (_loadingContext || _ownerUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Unable to create booking. Please try again shortly.")),
      );
      return;
    }
    if (_totalPrice == 0 || _selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select at least one service to continue.")));
      return;
    }

    setState(() => _isProcessing = true);

    _createFirestoreBooking().then((_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.green,
          content: Text("Booking created successfully."),
        ),
      );
      Navigator.pop(context);
    }).catchError((e) {
      debugPrint('Error creating booking: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Failed to create booking. Please try again."),
        ),
      );
    });
  }

  Future<void> _loadUserContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _loadingContext = false);
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String? ownerUid = user.uid;
      String? role;
      String? branchId;

      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>? ?? {};
        role = (data['role'] ?? '').toString();
        branchId = (data['branchId'] ?? '').toString();

        if (role == 'salon_owner') {
          ownerUid = user.uid;
        } else if (data['ownerUid'] != null &&
            data['ownerUid'].toString().isNotEmpty) {
          ownerUid = data['ownerUid'].toString();
        }
      }

      if (!mounted) return;
      setState(() {
        _ownerUid = ownerUid;
        _userRole = role;
        _userBranchId = branchId?.isNotEmpty == true ? branchId : null;
      });

      await _loadInitialData();
    } catch (e) {
      debugPrint('Error loading user context: $e');
      if (!mounted) return;
      setState(() {
        _loadingContext = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    if (_ownerUid == null) {
      setState(() {
        _loadingContext = false;
        _loadingData = false;
      });
      return;
    }
    try {
      final db = FirebaseFirestore.instance;

      final branchesSnap = await db
          .collection('branches')
          .where('ownerUid', isEqualTo: _ownerUid)
          .get();

      final servicesSnap = await db
          .collection('services')
          .where('ownerUid', isEqualTo: _ownerUid)
          .get();

      final staffSnap = await db
          .collection('users')
          .where('ownerUid', isEqualTo: _ownerUid)
          .get();

      final branches = branchesSnap.docs.map((d) {
        final data = d.data();
        debugPrint('[BranchLoad] Branch "${data['name']}" id=${d.id}');
        return {
          'id': d.id,
          'name': (data['name'] ?? 'Branch').toString(),
          'address': (data['address'] ?? '').toString(),
        };
      }).toList();

      final services = servicesSnap.docs.map((d) {
        final data = d.data();
        final branchesList = (data['branches'] is List)
            ? List<String>.from(
                (data['branches'] as List).map((e) => e.toString()))
            : <String>[];
        debugPrint('[ServiceLoad] Service "${data['name']}" id=${d.id}, branches=$branchesList');
        return {
          'id': d.id,
          'name': (data['name'] ?? 'Service').toString(),
          'price': (data['price'] ?? 0),
          'duration': (data['duration'] ?? 60),
          'imageUrl': data['imageUrl'] ?? data['image'],
          'branches': branchesList,
          'staffIds': (data['staffIds'] is List)
              ? List<String>.from(
                  (data['staffIds'] as List).map((e) => e.toString()))
              : <String>[],
        };
      }).toList();

      final staff = staffSnap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name':
              (data['displayName'] ?? data['name'] ?? 'Unknown').toString(),
          'status': (data['status'] ?? 'Active').toString(),
          'avatar': data['avatar'] ?? data['photoURL'],
          'branchId': (data['branchId'] ?? '').toString(),
        };
      }).where((m) {
        final status = (m['status'] ?? 'Active').toString();
        return status != 'Suspended';
      }).toList();

      if (!mounted) return;
      setState(() {
        _branches = branches;
        _services = services;
        _staff = [
          {'id': 'any', 'name': 'Any Staff', 'avatar': null},
          ...staff,
        ];

        // Default branch for branch admins
        if (_userRole == 'salon_branch_admin' && _userBranchId != null) {
          final br = branches.firstWhere(
              (b) => b['id'] == _userBranchId,
              orElse: () => {});
          if (br.isNotEmpty) {
            _selectedBranchId = br['id'] as String;
            _selectedBranchLabel = br['name'] as String;
          }
        }

        _loadingContext = false;
        _loadingData = false;
      });
    } catch (e) {
      debugPrint('Error loading booking data: $e');
      if (!mounted) return;
      setState(() {
        _dataError = 'Failed to load booking data.';
        _loadingContext = false;
        _loadingData = false;
      });
    }
  }

  // Generate a booking code similar to admin panel
  String _generateBookingCode() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final dateTime = '$month$day$hour';
    final random = (DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'BK-$year-$dateTime-$random';
  }

  Future<void> _createFirestoreBooking() async {
    final now = DateTime.now();
    final DateTime date = _selectedDate ?? now;

    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Get all selected services
    final List<Map<String, dynamic>> selectedServices = _selectedServiceIds
        .map((id) => _services.firstWhere((s) => s['id'] == id, orElse: () => {}))
        .where((s) => s.isNotEmpty)
        .toList();

    // Build service names and IDs as comma-separated strings
    final serviceNames = selectedServices.map((s) => s['name'] ?? 'Service').join(', ');
    final serviceIds = selectedServices.map((s) => s['id']).join(',');

    // Get first service time as main booking time
    final firstServiceId = _selectedServiceIds.isNotEmpty ? _selectedServiceIds.first : '';
    final firstTime = _serviceTimeSelections[firstServiceId] ?? TimeOfDay.fromDateTime(now);
    final mainTimeStr = '${firstTime.hour.toString().padLeft(2, '0')}:${firstTime.minute.toString().padLeft(2, '0')}';

    // Determine main staff (if all same, use that; otherwise "Multiple Staff")
    final uniqueStaffIds = _serviceStaffSelections.values.where((s) => s != 'any').toSet();
    String? mainStaffId;
    String mainStaffName = 'Any Available';
    if (uniqueStaffIds.length == 1) {
      mainStaffId = uniqueStaffIds.first;
      final match = _staff.firstWhere((s) => s['id'] == mainStaffId, orElse: () => {});
      if (match.isNotEmpty) {
        mainStaffName = (match['name'] ?? 'Staff').toString();
      }
    } else if (uniqueStaffIds.length > 1) {
      mainStaffName = 'Multiple Staff';
    }

    final clientName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final notes = _notesController.text.trim();

    // Build services array with per-service time and staff
    final servicesArray = selectedServices.map((service) {
      final svcId = service['id'] as String;
      final svcTime = _serviceTimeSelections[svcId] ?? firstTime;
      final svcTimeStr = '${svcTime.hour.toString().padLeft(2, '0')}:${svcTime.minute.toString().padLeft(2, '0')}';
      final svcStaffId = _serviceStaffSelections[svcId];
      String? staffId;
      String staffName = 'Any Available';
      if (svcStaffId != null && svcStaffId != 'any') {
        staffId = svcStaffId;
        final match = _staff.firstWhere((s) => s['id'] == svcStaffId, orElse: () => {});
        if (match.isNotEmpty) {
          staffName = (match['name'] ?? 'Staff').toString();
        }
      }
      return {
        'duration': (service['duration'] as num?)?.toInt() ?? 60,
        'id': service['id'],
        'name': service['name'],
        'price': (service['price'] as num?)?.toInt() ?? 0,
        'staffId': staffId,
        'staffName': staffName,
        'time': svcTimeStr,
      };
    }).toList();

    final bookingCode = _generateBookingCode();
    
    final bookingData = <String, dynamic>{
      'bookingCode': bookingCode,
      'bookingSource': 'AdminBooking',
      'branchId': _selectedBranchId,
      'branchName': _selectedBranchLabel,
      'client': clientName,
      'clientEmail': email.isNotEmpty ? email : null,
      'clientPhone': phone.isNotEmpty ? phone : null,
      'createdAt': FieldValue.serverTimestamp(),
      'customerUid': null, // Walk-in customers don't have UID
      'date': dateStr,
      'duration': _totalDuration,
      'notes': notes.isNotEmpty ? notes : null,
      'ownerUid': _ownerUid,
      'price': _totalPrice,
      'serviceId': serviceIds,
      'serviceName': serviceNames,
      'services': servicesArray,
      'staffId': mainStaffId,
      'staffName': mainStaffName,
      'status': 'Pending',
      'time': mainTimeStr,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    debugPrint('Creating booking with data: $bookingData');

    await FirebaseFirestore.instance
        .collection('bookings')
        .add(bookingData);
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loadingContext || _loadingData
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildStepContent(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.xmark, color: AppColors.text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              const Text('Create Booking',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
              const SizedBox(height: 4),
              Text(
                'Step ${_currentStep + 1} of 3',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentStep = 0;
                _selectedBranchLabel = null;
                _selectedServiceIds = {};
                _selectedDate = null;
                _serviceTimeSelections = {};
                _serviceStaffSelections = {};
                _nameController.clear();
                _phoneController.clear();
                _emailController.clear();
                _notesController.clear();
              });
            },
            child: const Text('Reset',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerForm() {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            TextField(
            controller: _nameController,
            decoration: _inputDecoration("Full Name *", "Enter customer name"),
              style: const TextStyle(color: AppColors.text),
            onChanged: (_) => setState(() {}), // Trigger rebuild for validation
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration("Phone *", "Enter phone number"),
            style: const TextStyle(color: AppColors.text),
            onChanged: (_) => setState(() {}), // Trigger rebuild for validation
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration("Email (optional)", "email@example.com"),
            style: const TextStyle(color: AppColors.text),
          ),
            const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: _inputDecoration("Additional Notes (optional)", "Any special requests or notes..."),
            style: const TextStyle(color: AppColors.text),
          ),
          ],
        ),
      );
  }

  Widget _buildServiceGrid() {
    // Require branch selection first
    if (_selectedBranchId == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(FontAwesomeIcons.mapLocationDot,
                size: 40, color: AppColors.muted.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text(
              'Select a branch first',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a location above to see available services',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    if (_services.isEmpty) {
      return const Text(
        'No services found. Please add services in the admin panel.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      );
    }

    // Filter services by selected branch.
    // Service.branches is a List<String> of branch document IDs.
    // - If the list is empty or null → service is available for ALL branches.
    // - If the list is non-empty → service is only available for those specific branch IDs.
    final List<Map<String, dynamic>> visibleServices = _services.where((srv) {
      final dynamic branchesRaw = srv['branches'];
      // If branches field is missing, null, or empty list → available everywhere
      if (branchesRaw == null) return true;
      if (branchesRaw is! List) return true;
      if (branchesRaw.isEmpty) return true;

      // branches is non-empty → check if selected branch is in the list
      final List<String> branchIds = branchesRaw.map((e) => e.toString()).toList();
      debugPrint('[ServiceFilter] Service "${srv['name']}" branches=$branchIds, selectedBranch=$_selectedBranchId');
      return branchIds.contains(_selectedBranchId);
    }).toList();

    debugPrint('[ServiceFilter] Total services=${_services.length}, visible=${visibleServices.length}, selectedBranch=$_selectedBranchId');

    if (visibleServices.isEmpty) {
      return const Text(
        'No services available for this branch.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: visibleServices.length,
      itemBuilder: (context, index) {
        return _buildServiceCard(visibleServices[index]);
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final serviceId = service['id'];
    final isSelected = _selectedServiceIds.contains(serviceId);
    debugPrint('[ServiceCard] Building card for ${service['name']} (id: $serviceId), isSelected: $isSelected, selectedIds: $_selectedServiceIds');
    final Color color = AppColors.primary;
    final int durationMinutes =
        (service['duration'] is num) ? (service['duration'] as num).toInt() : 0;
    final String durationLabel =
        durationMinutes >= 60 && durationMinutes % 60 == 0
            ? '${durationMinutes ~/ 60}h'
            : '${durationMinutes}m';
    final String? imageUrl =
        service['imageUrl'] != null && service['imageUrl'].toString().isNotEmpty
            ? service['imageUrl'].toString()
            : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint('[ServiceCard] Tapped: ${service['name']} (id: $serviceId)');
        _selectService(serviceId);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4))],
          border: isSelected ? null : Border.all(color: AppColors.border),
          gradient: isSelected ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large Image Section with checkmark
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 1.2,
              child: imageUrl != null
                        ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                              child: Center(
                                child: Icon(
                                  FontAwesomeIcons.scissors,
                                  color: isSelected ? Colors.white : color,
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                            child: Center(
                      child: Icon(
                        FontAwesomeIcons.scissors,
                        color: isSelected ? Colors.white : color,
                                size: 32,
                      ),
                    ),
            ),
                  ),
                ),
                // Checkmark badge for selected services
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Service Info Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.text,
                      fontSize: 13,
                  ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                ),
                  const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.2) : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                      durationLabel,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ),
                    Text(
                      '\$${service['price']}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                    ),
                  ],
                )
              ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // Get staff who can perform a specific service and work at the selected branch
  List<Map<String, dynamic>> _getAvailableStaffForService(String serviceId) {
    final service = _services.firstWhere((s) => s['id'] == serviceId, orElse: () => {});
    if (service.isEmpty) return [];

    final List<String> serviceStaffIds = service['staffIds'] != null
        ? (service['staffIds'] as List).map((e) => e.toString()).toList()
        : [];

    return _staff.where((staff) {
      // Check if staff is active
      if (staff['status'] != 'Active') return false;

      // Check if staff works at selected branch
      if (_selectedBranchId != null && staff['branchId'] != _selectedBranchId) {
        return false;
      }

      // Check if staff can perform this service (if service has staffIds restriction)
      if (serviceStaffIds.isNotEmpty && !serviceStaffIds.contains(staff['id'])) {
        return false;
      }

      return true;
    }).toList();
  }

  Widget _buildDatePicker() {
    final dateText = _selectedDate != null
        ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
        : 'Select date';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        leading: const Icon(FontAwesomeIcons.calendarDay,
            color: AppColors.primary, size: 18),
        title: const Text(
          'Date',
          style: TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        subtitle: Text(
          dateText,
          style: const TextStyle(color: AppColors.muted),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate ?? now,
            firstDate: now,
            lastDate: now.add(const Duration(days: 365)),
          );
          if (picked != null) {
            setState(() {
              _selectedDate = picked;
              // Clear time/staff selections when date changes
              _serviceTimeSelections = {};
              _serviceStaffSelections = {};
            });
          }
        },
      ),
    );
  }

  Widget _buildPerServiceTimeStaffSelector() {
    if (_selectedDate == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
              child: Column(
          children: [
            Icon(FontAwesomeIcons.calendarDay,
                size: 40, color: AppColors.muted.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text(
              'Select a date first',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    final selectedServices = _selectedServiceIds
        .map((id) => _services.firstWhere((s) => s['id'] == id, orElse: () => {}))
        .where((s) => s.isNotEmpty)
        .toList();

    if (selectedServices.isEmpty) {
      return const Text('No services selected', style: TextStyle(color: AppColors.muted));
    }

    return Column(
      children: selectedServices.map((service) {
        final serviceId = service['id'] as String;
        final serviceName = service['name'] ?? 'Service';
        final duration = (service['duration'] as num?)?.toInt() ?? 60;
        final selectedTime = _serviceTimeSelections[serviceId];
        final selectedStaffId = _serviceStaffSelections[serviceId] ?? 'any';
        final availableStaff = _getAvailableStaffForService(serviceId);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(FontAwesomeIcons.scissors, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          '${duration}min • \$${service['price']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedTime != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check, color: AppColors.green, size: 16),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Time selector
              const Text(
                'Select Time',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              _buildTimeSlots(serviceId, duration),

              const SizedBox(height: 16),

              // Staff selector
              const Text(
                'Select Staff',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              _buildStaffChips(serviceId, availableStaff, selectedStaffId),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSlots(String serviceId, int durationMinutes) {
    // Generate time slots from 9 AM to 6 PM
    final List<TimeOfDay> slots = [];
    for (int hour = 9; hour < 18; hour++) {
      slots.add(TimeOfDay(hour: hour, minute: 0));
      slots.add(TimeOfDay(hour: hour, minute: 30));
    }

    final selectedTime = _serviceTimeSelections[serviceId];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((time) {
        final isSelected = selectedTime != null &&
            selectedTime.hour == time.hour &&
            selectedTime.minute == time.minute;
        final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        return GestureDetector(
          onTap: () {
            setState(() {
              _serviceTimeSelections = Map.from(_serviceTimeSelections);
              _serviceTimeSelections[serviceId] = time;
            });
          },
                    child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              timeStr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStaffChips(String serviceId, List<Map<String, dynamic>> availableStaff, String selectedStaffId) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // "Any Available" option
        GestureDetector(
          onTap: () {
            setState(() {
              _serviceStaffSelections = Map.from(_serviceStaffSelections);
              _serviceStaffSelections[serviceId] = 'any';
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selectedStaffId == 'any' ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selectedStaffId == 'any' ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FontAwesomeIcons.shuffle,
                  size: 12,
                  color: selectedStaffId == 'any' ? Colors.white : AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Any',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selectedStaffId == 'any' ? Colors.white : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Individual staff members
        ...availableStaff.map((staff) {
          final staffId = staff['id'] as String;
          final staffName = staff['name'] ?? 'Staff';
          final isSelected = selectedStaffId == staffId;

          return GestureDetector(
            onTap: () {
              setState(() {
                _serviceStaffSelections = Map.from(_serviceStaffSelections);
                _serviceStaffSelections[serviceId] = staffId;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.muted.withOpacity(0.3),
                    backgroundImage: staff['avatar'] != null
                        ? NetworkImage(staff['avatar'])
                        : null,
                      child: staff['avatar'] == null
                        ? Icon(Icons.person, size: 12, color: isSelected ? Colors.white : AppColors.muted)
                          : null,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    staffName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (availableStaff.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Text(
              'No specific staff available',
              style: TextStyle(fontSize: 12, color: AppColors.muted, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    String primaryLabel;
    VoidCallback? onPrimary;

    final canStep0Next =
        _selectedBranchLabel != null && _selectedServiceIds.isNotEmpty;
    // All services must have a time selected
    final allServicesHaveTime = _selectedServiceIds.every((id) => _serviceTimeSelections.containsKey(id));
    final canStep1Next =
        _selectedDate != null && allServicesHaveTime;

    if (_currentStep == 0) {
      primaryLabel = 'Next';
      if (canStep0Next && !_isProcessing) {
        onPrimary = () => setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      primaryLabel = 'Next';
      if (canStep1Next && !_isProcessing) {
        onPrimary = () => setState(() => _currentStep = 2);
      }
    } else {
      primaryLabel = 'Confirm Booking';
      // Require name and phone
      final hasRequiredFields = _nameController.text.trim().isNotEmpty && 
                                _phoneController.text.trim().isNotEmpty;
      if (!_isProcessing && hasRequiredFields) {
        onPrimary = _confirmBooking;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Text('\$${_totalPrice.toInt()}',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
            ],
          ),
          SizedBox(
            width: 200,
            height: 56,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    onPrimary == null ? Colors.grey.shade300 : Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: onPrimary == null
                      ? null
                      : const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent]),
                  color: onPrimary == null
                      ? Colors.grey.shade300
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: onPrimary == null
                      ? []
                      : [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_currentStep == 2)
                              const Icon(FontAwesomeIcons.check,
                                  color: Colors.white, size: 18),
                            if (_currentStep == 2) const SizedBox(width: 8),
                            Text(
                              primaryLabel,
                              style: TextStyle(
                                color: onPrimary == null
                                    ? Colors.grey.shade600
                                    : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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

  // --- Step content helpers ---

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              "Select Branch",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
            ),
            const SizedBox(height: 12),
            _buildBranchSelector(),
            const SizedBox(height: 24),
            Row(
              children: [
            const Text(
              "Select Services",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
                ),
                if (_selectedServiceIds.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedServiceIds.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _buildServiceGrid(),
            const SizedBox(height: 100),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              "Select Date",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
            ),
            const SizedBox(height: 16),
            _buildDatePicker(),
            const SizedBox(height: 24),
            Text(
              "Select Time & Staff for Each Service",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _selectedDate == null ? AppColors.muted : AppColors.text),
            ),
            const SizedBox(height: 16),
            _buildPerServiceTimeStaffSelector(),
            const SizedBox(height: 100),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              "Customer Details",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
            ),
            const SizedBox(height: 16),
            _buildCustomerForm(),
            const SizedBox(height: 24),
            _buildSummaryCard(),
            const SizedBox(height: 100),
          ],
        );
    }
  }

  Widget _buildBranchSelector() {
    if (_branches.isEmpty) {
      return const Text(
        'No branches found. Please create a branch in the admin panel.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      );
    }
    return Column(
      children: _branches.map((branch) {
        final name = (branch['name'] ?? 'Branch').toString();
        final address = (branch['address'] ?? '').toString();
        final isSelected = _selectedBranchId == branch['id'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              debugPrint('[BranchSelect] Selected branch id=${branch['id']}, name=$name');
              setState(() {
                _selectedBranchId = branch['id'] as String;
                _selectedBranchLabel = name;
                // Clear service selection when branch changes
                _selectedServiceIds = {};
              });
            },
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color:
                        isSelected ? AppColors.primary : AppColors.border),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.locationDot,
                    size: 14,
                    color:
                        isSelected ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : AppColors.text,
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white70
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      FontAwesomeIcons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCard() {
    final branch = _selectedBranchLabel ?? 'Not selected';
    
    // Get selected services
    final selectedServices = _selectedServiceIds
        .map((id) => _services.firstWhere((s) => s['id'] == id, orElse: () => {}))
        .where((s) => s.isNotEmpty)
        .toList();
    
    final dateText = _selectedDate != null
        ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
        : 'Not selected';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.text),
          ),
          const SizedBox(height: 12),
          _summaryRow('Branch', branch),
          _summaryRow('Date', dateText),
          const Divider(height: 20),
          
          // Services section with per-service time/staff
          Text(
            'Services (${selectedServices.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
          ),
          const SizedBox(height: 8),
          ...selectedServices.map((service) {
            final svcId = service['id'] as String;
            final svcTime = _serviceTimeSelections[svcId];
            final svcStaffId = _serviceStaffSelections[svcId];
            
            String staffName = 'Any Available';
            if (svcStaffId != null && svcStaffId != 'any') {
              final match = _staff.firstWhere((s) => s['id'] == svcStaffId, orElse: () => {});
              if (match.isNotEmpty) {
                staffName = match['name'] ?? 'Staff';
              }
            }
            
            final timeStr = svcTime != null
                ? '${svcTime.hour.toString().padLeft(2, '0')}:${svcTime.minute.toString().padLeft(2, '0')}'
                : 'Not set';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          service['name'] ?? 'Service',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                        ),
                      ),
                      Text(
                        '\$${service['price']}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(FontAwesomeIcons.clock, size: 10, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      const SizedBox(width: 12),
                      const Icon(FontAwesomeIcons.user, size: 10, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          staffName,
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          
          const Divider(height: 20),
          _summaryRow('Total Duration', '${_totalDuration}min'),
          _summaryRow('Total Price', '\$$_totalPrice'),
          const Divider(height: 20),
          _summaryRow(
            'Customer',
            _nameController.text.isNotEmpty ? _nameController.text : 'Not entered',
          ),
          if (_phoneController.text.isNotEmpty)
            _summaryRow('Phone', _phoneController.text),
          if (_emailController.text.isNotEmpty)
            _summaryRow('Email', _emailController.text),
          if (_notesController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Notes:', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _notesController.text,
                style: const TextStyle(fontSize: 12, color: AppColors.text),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.muted),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String? label, String? hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
    );
  }
}


