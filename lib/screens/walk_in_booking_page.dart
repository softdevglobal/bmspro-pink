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
  int _bookingType = 0; // 0: Anonymous, 1: Profile
  int _currentStep = 0; // 0: Branch & Services, 1: Date & Staff, 2: Details

  // Step 1 – branch & services
  String? _selectedBranchLabel;
  String _selectedServiceId = ''; // single service for now

  // Step 2 – date & staff
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedStaffId = 'any'; // ID of selected staff

  bool _isProcessing = false;

  // Auth / owner context
  String? _ownerUid;
  String? _userRole;
  String? _userBranchId;
  bool _loadingContext = true;
  String? _selectedBranchId;

  // Controllers
  final TextEditingController _guestIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

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
    // Generate Guest ID
    final now = DateTime.now();
    _guestIdController.text = "Guest #${now.hour}${now.minute}${now.second}";
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
    _guestIdController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // --- Logic Helpers ---
  double get _totalPrice {
    if (_selectedServiceId.isNotEmpty) {
      final service = _services.firstWhere((s) => s['id'] == _selectedServiceId, orElse: () => {});
      if (service.isNotEmpty) {
        return (service['price'] as num).toDouble();
      }
    }
    return 0.0;
  }

  void _toggleBookingType(int type) {
    setState(() {
      _bookingType = type;
    });
  }

  void _selectService(String id) {
    setState(() {
      if (_selectedServiceId == id) {
        _selectedServiceId = ''; // Deselect
      } else {
        _selectedServiceId = id;
      }
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
    if (_totalPrice == 0 || _selectedServiceId.isEmpty) {
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

  Future<void> _createFirestoreBooking() async {
    final now = DateTime.now();
    final DateTime date = _selectedDate ?? now;
    final TimeOfDay time = _selectedTime ?? TimeOfDay.fromDateTime(now);

    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    // Resolve main service details from real services list
    Map<String, dynamic> service = _services
        .firstWhere((s) => s['id'] == _selectedServiceId, orElse: () => {});
    if (service.isEmpty) {
      // Fallback: use a generic service
      service = {
        'id': _selectedServiceId,
        'name': 'Service',
        'price': _totalPrice,
        'duration': 60,
      };
    }

    // Staff details
    String? staffId;
    String staffName = 'Any Available';
    if (_selectedStaffId != 'any') {
      staffId = _selectedStaffId;
      final match = _staff.firstWhere(
          (s) => s['id'] == _selectedStaffId,
          orElse: () => {});
      if (match.isNotEmpty) {
        staffName = (match['name'] ?? staffName).toString();
      }
    }

    final clientName =
        _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Walk-in';
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    final bookingData = <String, dynamic>{
      'ownerUid': _ownerUid,
      'client': clientName,
      'clientEmail': email.isNotEmpty ? email : null,
      'clientPhone': phone.isNotEmpty ? phone : null,
      'notes': null,
      'serviceId': service['id'],
      'serviceName': service['name'],
      'staffId': staffId,
      'staffName': staffName,
      'branchId': _userBranchId,
      'branchName': _selectedBranchLabel,
      'date': dateStr,
      'time': timeStr,
      'duration': (service['duration'] as num?)?.toInt() ?? 60,
      'status': 'Pending',
      'price': _totalPrice,
      'services': [
        {
          'id': service['id'],
          'name': service['name'],
          'price': service['price'] ?? _totalPrice,
          'duration': (service['duration'] as num?)?.toInt() ?? 60,
          'time': timeStr,
          'staffId': staffId,
          'staffName': staffName,
        }
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('bookingRequests')
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
                _selectedServiceId = '';
                _selectedDate = null;
                _selectedTime = null;
                _selectedStaffId = 'any';
                _nameController.clear();
                _phoneController.clear();
                _emailController.clear();
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

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _toggleBtn('Anonymous', FontAwesomeIcons.userSecret, 0),
          _toggleBtn('Client Profile', FontAwesomeIcons.user, 1),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, IconData icon, int index) {
    final isSelected = _bookingType == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleBookingType(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
            color: isSelected ? null : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerForm() {
    if (_bookingType == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Guest ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
            const SizedBox(height: 8),
            TextField(
              controller: _guestIdController,
              readOnly: true,
              style: const TextStyle(color: AppColors.text),
              decoration: _inputDecoration(null, null),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: _inputDecoration("Full Name *", "Enter name")),
            const SizedBox(height: 12),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _inputDecoration("Phone *", "04XX XXX XXX")),
            const SizedBox(height: 12),
            TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration("Email", "email@example.com")),
          ],
        ),
      );
    }
  }

  Widget _buildServiceGrid() {
    // Require branch selection first
    if (_selectedBranchId == null) {
      return Container(
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
        childAspectRatio: 1.3,
      ),
      itemCount: visibleServices.length,
      itemBuilder: (context, index) {
        return _buildServiceCard(visibleServices[index]);
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final isSelected = _selectedServiceId == service['id'];
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
      onTap: () => _selectService(service['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4))],
          border: isSelected ? null : Border.all(color: Colors.transparent),
          gradient: isSelected ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Icon(
                        FontAwesomeIcons.scissors,
                        color: isSelected ? Colors.white : color,
                        size: 18,
                      ),
                    ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.text,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      durationLabel,
                      style: TextStyle(color: isSelected ? Colors.white70 : AppColors.muted, fontSize: 12),
                    ),
                    Text(
                      '\$${service['price']}',
                      style: TextStyle(color: isSelected ? Colors.white : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStaffSelector() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _staff.length,
        itemBuilder: (context, index) {
          final staff = _staff[index];
          final isSelected = _selectedStaffId == staff['id'];
          return GestureDetector(
            onTap: () => setState(() => _selectedStaffId = staff['id']),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
                    ),
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        image: staff['avatar'] != null
                            ? DecorationImage(image: NetworkImage(staff['avatar']), fit: BoxFit.cover)
                            : null,
                      ),
                      child: staff['avatar'] == null
                          ? const Center(child: Icon(FontAwesomeIcons.users, color: AppColors.primary, size: 20))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    staff['name'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primary : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    String primaryLabel;
    VoidCallback? onPrimary;

    final canStep0Next =
        _selectedBranchLabel != null && _selectedServiceId.isNotEmpty;
    final canStep1Next =
        _selectedDate != null && _selectedTime != null;

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
      if (!_isProcessing) {
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
            const Text(
              "Select Services",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
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
              "Choose Date & Time",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
            ),
            const SizedBox(height: 16),
            _buildDateTimePicker(),
            const SizedBox(height: 24),
            const Text(
              "Assign Staff",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
            ),
            const SizedBox(height: 16),
            _buildStaffSelector(),
            const SizedBox(height: 100),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildToggle(),
            const SizedBox(height: 24),
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
                _selectedServiceId = '';
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

  Widget _buildDateTimePicker() {
    final dateText = _selectedDate != null
        ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
        : 'Select date';
    final timeText = _selectedTime != null
        ? _selectedTime!.format(context)
        : 'Select time';

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
        children: [
          ListTile(
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
                });
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(FontAwesomeIcons.clock,
                color: AppColors.primary, size: 18),
            title: const Text(
              'Time',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.text),
            ),
            subtitle: Text(
              timeText,
              style: const TextStyle(color: AppColors.muted),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime ??
                    TimeOfDay.fromDateTime(DateTime.now()),
              );
              if (picked != null) {
                setState(() {
                  _selectedTime = picked;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final branch = _selectedBranchLabel ?? 'Not selected';
    final service = _services.firstWhere(
        (s) => s['id'] == _selectedServiceId,
        orElse: () => {});
    final serviceName =
        service.isNotEmpty ? service['name'] as String : 'Not selected';
    final dateText = _selectedDate != null
        ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
        : 'Not selected';
    final timeText = _selectedTime != null
        ? _selectedTime!.format(context)
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
          _summaryRow('Service', serviceName),
          _summaryRow('Date', dateText),
          _summaryRow('Time', timeText),
          _summaryRow(
            'Customer',
            _bookingType == 0
                ? _guestIdController.text
                : (_nameController.text.isNotEmpty
                    ? _nameController.text
                    : 'Walk-in'),
          ),
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


