import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/animated_toggle.dart';

class ServiceDetail {
  final String name;
  final double price;
  final String staffName;
  final String staffId;
  final int duration;
  
  ServiceDetail({
    required this.name,
    this.price = 0,
    this.staffName = '',
    this.staffId = '',
    this.duration = 0,
  });
}

class Appointment {
  final String time;
  final String client;
  final String service;
  final String room;
  final IconData icon;
  final String staffId;
  final String status;
  final double price;
  final String staffName;
  final String phone;
  final String email;
  final String bookingId;
  final List<ServiceDetail> services;
  
  Appointment({
    required this.time,
    required this.client,
    required this.service,
    required this.room,
    required this.icon,
    required this.staffId,
    this.status = 'Confirmed',
    this.price = 0,
    this.staffName = '',
    this.phone = '',
    this.email = '',
    this.bookingId = '',
    this.services = const [],
  });
}

class DaySchedule {
  final String? branch; // 'Main St', 'Downtown', 'Westside'
  final bool isOffDay;
  final List<Appointment> items;
  DaySchedule({this.branch, this.isOffDay = false, this.items = const []});
}

class BranchTheme {
  final Color color;
  final Color lightBg;
  final List<Color> gradient;
  BranchTheme({
    required this.color,
    required this.lightBg,
    required this.gradient,
  });
}

class AppConfig {
  static const primary = Color(0xFFFF2D8F);
  static const accent = Color(0xFFFF6FB5);
  static const background = Color(0xFFFFF5FA);
  static const card = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF9E9E9E);
  static const border = Color(0xFFF2D2E9);
  static final Map<String, BranchTheme> branches = {
    'Main St': BranchTheme(
      color: Color(0xFFFF2D8F),
      lightBg: Color(0xFFFFF5FA),
      gradient: [Color(0xFFFF2D8F), Color(0xFFFF6FB5)],
    ),
    'Downtown': BranchTheme(
      color: Color(0xFF3B82F6),
      lightBg: Color(0xFFEFF6FF),
      gradient: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    ),
    'Westside': BranchTheme(
      color: Color(0xFF10B981),
      lightBg: Color(0xFFECFDF5),
      gradient: [Color(0xFF10B981), Color(0xFF34D399)],
    ),
  };
}

class CalenderScreen extends StatefulWidget {
  const CalenderScreen({super.key});

  @override
  State<CalenderScreen> createState() => _CalenderScreenState();
}

class _CalenderScreenState extends State<CalenderScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  Map<int, DaySchedule> _scheduleData = {};
  
  // Role & filtering state
  String? _currentUserRole;
  String? _currentUserId;
  String? _ownerUid;
  String? _branchId;
  bool _isBranchView = false; // false = My Schedule, true = Branch Schedule
  bool _isLoadingRole = true;

  // Live bookings state
  bool _isLoadingBookings = true;
  String? _bookingsError;
  final List<Map<String, dynamic>> _allBookings = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bookingsSub;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUserId = user.uid;
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (mounted && doc.exists) {
          final userData = doc.data();
          setState(() {
            _currentUserRole = userData?['role'];
            _ownerUid = (userData?['ownerUid'] ?? user.uid).toString();
            _branchId = (userData?['branchId'] ?? '').toString();
            _isLoadingRole = false;
          });

          _startBookingsListener();
        }
      } else {
         if (mounted) setState(() => _isLoadingRole = false);
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    super.dispose();
  }

  void _startBookingsListener() {
    final ownerUid = _ownerUid;
    if (ownerUid == null || ownerUid.isEmpty) {
      setState(() {
        _isLoadingBookings = false;
        _bookingsError = 'Missing owner UID';
      });
      return;
    }

    _bookingsSub?.cancel();
    setState(() {
      _isLoadingBookings = true;
      _bookingsError = null;
      _scheduleData = {};
      _allBookings.clear();
    });

    _bookingsSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .listen((snap) {
      _allBookings
        ..clear()
        ..addAll(snap.docs.map((d) => d.data()));
      _rebuildScheduleFromBookings();
    }, onError: (e) {
      debugPrint('Error listening to bookings: $e');
      if (mounted) {
        setState(() {
          _isLoadingBookings = false;
          _bookingsError = e.toString();
        });
      }
    });
  }

  void _rebuildScheduleFromBookings() {
    final Map<int, DaySchedule> byDay = {};
    final bool isOwner = _currentUserRole == 'salon_owner';

    for (final data in _allBookings) {
      // Status filter: salon owners see all, others see confirmed only
      final statusRaw = (data['status'] ?? '').toString().toLowerCase();
      if (!isOwner && statusRaw != 'confirmed') continue;
      
      // Skip cancelled bookings for everyone
      if (statusRaw == 'cancelled' || statusRaw == 'canceled') continue;

      final dateStr = (data['date'] ?? '').toString();
      if (dateStr.isEmpty) continue;

      DateTime date;
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        continue;
      }

      // Match currently focused month
      if (date.year != _focusedMonth.year || date.month != _focusedMonth.month) {
        continue;
      }

      // Role-based inclusion
      if (!_shouldIncludeBookingForCurrentUser(data, date)) {
        continue;
      }

      final int dayKey = date.day;

      final branchName = (data['branchName'] ?? '').toString();
      final clientName = (data['client'] ?? data['customerName'] ?? 'Walk-in').toString();
      final clientPhone = (data['phone'] ?? data['customerPhone'] ?? '').toString();
      final clientEmail = (data['email'] ?? data['customerEmail'] ?? '').toString();
      final bookingId = (data['id'] ?? '').toString();

      // Derive service name, price, and individual service details
      String serviceName = (data['serviceName'] ?? '').toString();
      double totalPrice = 0;
      List<ServiceDetail> serviceDetails = [];
      
      // Try to get price from top level first
      if (data['price'] != null) {
        totalPrice = double.tryParse(data['price'].toString()) ?? 0;
      } else if (data['totalPrice'] != null) {
        totalPrice = double.tryParse(data['totalPrice'].toString()) ?? 0;
      }
      
      // Parse individual services
      if (data['services'] is List) {
        final list = data['services'] as List;
        for (final svc in list) {
          if (svc is Map) {
            final svcName = (svc['name'] ?? 'Service').toString();
            final svcPrice = double.tryParse((svc['price'] ?? '0').toString()) ?? 0;
            final svcStaffName = (svc['staffName'] ?? '').toString();
            final svcStaffId = (svc['staffId'] ?? '').toString();
            final svcDuration = int.tryParse((svc['duration'] ?? '0').toString()) ?? 0;
            
            serviceDetails.add(ServiceDetail(
              name: svcName,
              price: svcPrice,
              staffName: svcStaffName,
              staffId: svcStaffId,
              duration: svcDuration,
            ));
            
            // Sum prices if not set at top level
            if (totalPrice == 0) {
              totalPrice += svcPrice;
            }
          }
        }
        
        // Set service name from first service or combine names
        if (serviceDetails.isNotEmpty) {
          if (serviceDetails.length == 1) {
            serviceName = serviceDetails.first.name;
          } else {
            serviceName = serviceDetails.map((s) => s.name).join(', ');
          }
        }
      }
      if (serviceName.isEmpty) serviceName = 'Service';

      // Get staff name summary
      String staffName = (data['staffName'] ?? '').toString();
      if (staffName.isEmpty && serviceDetails.isNotEmpty) {
        final Set<String> staffNames = {};
        for (final svc in serviceDetails) {
          if (svc.staffName.isNotEmpty) staffNames.add(svc.staffName);
        }
        if (staffNames.length == 1) {
          staffName = staffNames.first;
        } else if (staffNames.length > 1) {
          staffName = '${staffNames.length} staff';
        }
      }

      // Format status properly (convert camelCase like "AwaitingStaffApproval" to "Awaiting Staff Approval")
      String status = _formatStatus(statusRaw);

      final timeStr = (data['time'] ?? '').toString();
      String timeLabel = timeStr;
      try {
        if (timeStr.isNotEmpty) {
          final t = DateFormat('HH:mm').parse(timeStr);
          timeLabel = DateFormat('h:mm a').format(t);
        }
      } catch (_) {}

      // Use branch name as "room" label for now
      final roomLabel = branchName.isNotEmpty ? branchName : 'Salon';

      // Icon heuristic
      IconData icon = FontAwesomeIcons.scissors;
      final lower = serviceName.toLowerCase();
      if (lower.contains('nail')) {
        icon = FontAwesomeIcons.handSparkles;
      } else if (lower.contains('facial') || lower.contains('spa')) {
        icon = FontAwesomeIcons.spa;
      } else if (lower.contains('massage')) {
        icon = FontAwesomeIcons.spa;
      } else if (lower.contains('extension')) {
        icon = FontAwesomeIcons.wandMagicSparkles;
      } else if (lower.contains('color') || lower.contains('colour')) {
        icon = FontAwesomeIcons.paintbrush;
      } else if (lower.contains('cut') || lower.contains('trim')) {
        icon = FontAwesomeIcons.scissors;
      } else if (lower.contains('wax')) {
        icon = FontAwesomeIcons.star;
      }

      final appt = Appointment(
        time: timeLabel,
        client: clientName,
        service: serviceName,
        room: roomLabel,
        icon: icon,
        staffId: _extractStaffId(data),
        status: status,
        price: totalPrice,
        staffName: staffName,
        phone: clientPhone,
        email: clientEmail,
        bookingId: bookingId,
        services: serviceDetails,
      );

      final existing = byDay[dayKey];
      if (existing == null) {
        byDay[dayKey] = DaySchedule(
          branch: branchName.isNotEmpty ? branchName : null,
          items: [appt],
        );
      } else {
        // Merge items and handle multiple branches
        final List<Appointment> items = List.of(existing.items)..add(appt);
        String? mergedBranch = existing.branch;
        if (mergedBranch == null && branchName.isNotEmpty) {
          mergedBranch = branchName;
        } else if (mergedBranch != null &&
            branchName.isNotEmpty &&
            branchName != mergedBranch) {
          mergedBranch = 'Multiple Branches';
        }
        byDay[dayKey] = DaySchedule(
          branch: mergedBranch,
          items: items,
          isOffDay: false,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _scheduleData = byDay;
      _isLoadingBookings = false;
    });
  }

  /// Converts camelCase/PascalCase status like "AwaitingStaffApproval" to "Awaiting Staff Approval"
  String _formatStatus(String raw) {
    if (raw.isEmpty) return 'Pending';
    
    // Insert space before each uppercase letter (except the first)
    final spaced = raw.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    
    // Capitalize first letter and return
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// Format status for display in UI - handles camelCase and provides short labels
  String _formatStatusDisplay(String status) {
    // Handle camelCase like "AwaitingStaffApproval" -> "Awaiting Staff Approval"
    String formatted = status.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    
    // Also handle fully lowercase versions
    final lower = formatted.toLowerCase();
    if (lower == 'awaitingstaffapproval' || lower.contains('awaiting')) {
      return 'Awaiting Approval';
    }
    if (lower.contains('partially')) {
      return 'Partial';
    }
    
    // Capitalize first letter of each word
    return formatted.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  bool _shouldIncludeBookingForCurrentUser(
      Map<String, dynamic> data, DateTime date) {
    final role = _currentUserRole;
    final uid = _currentUserId;
    final branchId = _branchId;

    // Salon owner: see all confirmed bookings for their salon
    if (role == 'salon_owner') return true;

    final bookingBranchId = (data['branchId'] ?? '').toString();

    // Branch admin: see only their branch in calendar;
    // per-staff vs branch-wide is handled later in _buildAppointmentsList.
    if (role == 'salon_branch_admin') {
      if (branchId != null &&
          branchId.isNotEmpty &&
          bookingBranchId.isNotEmpty &&
          bookingBranchId != branchId) {
        return false;
      }
      return true;
    }

    // Staff: only their own bookings
    if (uid == null || uid.isEmpty) return false;
    return _isBookingForStaff(data, uid);
  }

  bool _isBookingForStaff(Map<String, dynamic> data, String staffUid) {
    final topLevelStaff = data['staffId'];
    if (topLevelStaff != null &&
        topLevelStaff.toString().isNotEmpty &&
        topLevelStaff.toString() == staffUid) {
      return true;
    }

    if (data['services'] is List) {
      final list = data['services'] as List;
      for (final item in list) {
        if (item is Map && item['staffId'] != null) {
          final sid = item['staffId'].toString();
          if (sid.isNotEmpty && sid == staffUid) {
            return true;
          }
        }
      }
    }
    return false;
  }

  String _extractStaffId(Map<String, dynamic> data) {
    final topLevelStaff = data['staffId'];
    if (topLevelStaff != null && topLevelStaff.toString().isNotEmpty) {
      return topLevelStaff.toString();
    }
    if (data['services'] is List) {
      final list = data['services'] as List;
      for (final item in list) {
        if (item is Map && item['staffId'] != null) {
          final sid = item['staffId'].toString();
          if (sid.isNotEmpty) {
            return sid;
          }
        }
      }
    }
    return '';
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + offset, 1);
    });
    _rebuildScheduleFromBookings();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole || _isLoadingBookings) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: AppConfig.primary),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildMonthSelector(),
          const SizedBox(height: 24),
          _buildSelectedDayHeader(),
          const SizedBox(height: 24),
          _buildAppointmentsList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final bool isBranchAdmin = _currentUserRole == 'salon_branch_admin';
    final bool isOwner = _currentUserRole == 'salon_owner';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: Column(
              children: [
                Text(
                  isOwner
                      ? 'Salon Schedule'
                      : (_isBranchView ? 'Branch Schedule' : 'My Schedule'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppConfig.text,
                  ),
                ),
                if (isBranchAdmin && !isOwner) ...[
                  const SizedBox(height: 12),
                  _buildViewToggle(),
                ],
              ],
            ),
          ),
        ),
        if (!_isBranchView || !isBranchAdmin) // Only show legend if complicated, or always? Keeping it simple.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(AppConfig.branches['Main St']!.color, 'Main St'),
              const SizedBox(width: 16),
              _legendItem(AppConfig.branches['Downtown']!.color, 'Downtown'),
              const SizedBox(width: 16),
              _legendItem(AppConfig.branches['Westside']!.color, 'Westside'),
            ],
          )
      ],
    );
  }

  Widget _buildViewToggle() {
    return SizedBox(
      width: 300,
      child: AnimatedToggle(
        backgroundColor: Colors.white,
        values: const ['My Schedule', 'Branch Schedule'],
        selectedIndex: _isBranchView ? 1 : 0,
        onChanged: (index) => setState(() => _isBranchView = index == 1),
      ),
    );
  }

  // Removed manual toggle buttons as we use AnimatedToggle now


  Widget _buildMonthSelector() {
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOffset =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _softShadowDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _changeMonth(-1),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(FontAwesomeIcons.chevronLeft,
                      size: 14, color: AppConfig.text),
                ),
              ),
              Column(
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_focusedMonth),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppConfig.text),
                  ),
                  const Text(
                    'Select a date to view details',
                    style: TextStyle(fontSize: 12, color: AppConfig.muted),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _changeMonth(1),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(FontAwesomeIcons.chevronRight,
                      size: 14, color: AppConfig.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => SizedBox(
                      width: 35,
                      child: Text(d,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppConfig.muted)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: daysInMonth + firstDayOffset,
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox();
              final day = index - firstDayOffset + 1;
              final currentDt =
                  DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final isSelected = _selectedDate.year == currentDt.year &&
                  _selectedDate.month == currentDt.month &&
                  _selectedDate.day == currentDt.day;
              final dayData = _scheduleData[day];
              Color? branchColor;
              if (dayData != null && dayData.branch != null) {
                // Safe access - only use color if branch exists in config
                final branchTheme = AppConfig.branches[dayData.branch];
                branchColor = branchTheme?.color ?? AppConfig.primary;
              }
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = currentDt;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: branchColor ?? AppConfig.primary, width: 2)
                        : Border.all(color: Colors.grey.shade100),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: (branchColor ?? Colors.black)
                                    .withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? (branchColor ?? AppConfig.primary)
                                : (dayData?.isOffDay == true
                                    ? AppConfig.muted.withOpacity(0.5)
                                    : AppConfig.text),
                          ),
                        ),
                      ),
                      if (dayData?.isOffDay == true)
                        const Positioned(
                          bottom: 4,
                          left: 0,
                          right: 0,
                          child: Text('OFF',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppConfig.muted)),
                        ),
                      // Show booking count badge for days with multiple bookings
                      if (dayData != null && dayData.items.length > 1)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: branchColor ?? AppConfig.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${dayData.items.length}',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (branchColor != null)
                        Positioned(
                          bottom: 6,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: branchColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        )
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayHeader() {
    final dayInt = _selectedDate.day;
    final data =
        _scheduleData[dayInt]; // Schedule generated from live bookings
    final bool isOwner = _currentUserRole == 'salon_owner';
    
    List<Color> gradient = [Colors.grey.shade400, Colors.grey.shade300];
    String branchName = "No Schedule";
    int bookingCount = 0;
    double dayRevenue = 0;
    
    if (data != null) {
      if (data.isOffDay) {
        branchName = "Day Off";
        gradient = [Colors.grey.shade400, Colors.grey.shade300];
      } else if (data.branch != null) {
        branchName = "${data.branch} Branch";
        final theme = _resolveBranchTheme(data.branch);
        gradient = theme.gradient;
      }
      bookingCount = data.items.length;
      // Calculate day's total revenue
      for (final appt in data.items) {
        dayRevenue += appt.price;
      }
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d').format(_selectedDate),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(FontAwesomeIcons.locationDot,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        branchName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Show booking count and revenue for owners
                if (isOwner && bookingCount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(FontAwesomeIcons.calendarCheck,
                                size: 10, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '$bookingCount booking${bookingCount > 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      if (dayRevenue > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(FontAwesomeIcons.dollarSign,
                                  size: 10, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                'AU\$${dayRevenue.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: bookingCount > 0
                  ? Text(
                      '$bookingCount',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(FontAwesomeIcons.calendarDay,
                      color: Colors.white, size: 24),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    final dayInt = _selectedDate.day;
    final data = _scheduleData[dayInt];
    if (data == null || (data.items.isEmpty && !data.isOffDay)) {
      return _emptyState(
          FontAwesomeIcons.calendarXmark, "No appointments scheduled.");
    }
    if (data.isOffDay) {
      return _emptyState(FontAwesomeIcons.mugHot, "Enjoy your day off!");
    }

    // Filter items based on role & view mode
    final filteredItems = data.items.where((appt) {
      // Salon owner: always see full salon schedule
      if (_currentUserRole == 'salon_owner') {
        return true;
      }

      // Branch admin: in branch view see all, otherwise personal
      if (_currentUserRole == 'salon_branch_admin' && _isBranchView) {
        return true; 
      }

      // Staff / default: only "my" appointments
      return _currentUserId != null && appt.staffId == _currentUserId;
    }).toList();

    if (filteredItems.isEmpty) {
       return _emptyState(
          FontAwesomeIcons.calendarXmark, "No appointments for you today.");
    }

    final bool isOwner = _currentUserRole == 'salon_owner';
    
    // Sort by time
    filteredItems.sort((a, b) => a.time.compareTo(b.time));

    return Column(
      children: filteredItems.map((appt) {
        final theme = _resolveBranchTheme(data.branch);
        
        // Dynamic status colors
        Color statusBgColor;
        Color statusTextColor;
        Color statusBorderColor;
        
        final statusLower = appt.status.toLowerCase();
        if (statusLower == 'pending' || statusLower.contains('awaiting') || statusLower.contains('partially')) {
          statusBgColor = Colors.amber.shade50;
          statusTextColor = Colors.amber.shade700;
          statusBorderColor = Colors.amber.shade200;
        } else if (statusLower == 'confirmed') {
          statusBgColor = Colors.green.shade50;
          statusTextColor = Colors.green.shade700;
          statusBorderColor = Colors.green.shade100;
        } else if (statusLower == 'completed') {
          statusBgColor = Colors.blue.shade50;
          statusTextColor = Colors.blue.shade700;
          statusBorderColor = Colors.blue.shade100;
        } else {
          statusBgColor = Colors.grey.shade50;
          statusTextColor = Colors.grey.shade700;
          statusBorderColor = Colors.grey.shade200;
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppConfig.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: theme.color.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                // Main content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: theme.gradient),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: theme.color.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Center(
                                child:
                                    Icon(appt.icon, color: Colors.white, size: 20)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appt.service,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppConfig.text),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (data.branch != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.lightBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          data.branch!.toUpperCase(),
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: theme.color),
                                        ),
                                      ),
                                    if (appt.price > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'AU\$${appt.price.toStringAsFixed(0)}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade700),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusBorderColor),
                              ),
                              child: Text(
                                _formatStatusDisplay(appt.status),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusTextColor),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                        ],
                      ),
                      
                      // Client info section (expanded for owner)
                      if (isOwner) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppConfig.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        appt.client.isNotEmpty 
                                            ? appt.client[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppConfig.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          appt.client,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppConfig.text,
                                          ),
                                        ),
                                        if (appt.phone.isNotEmpty || appt.email.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              appt.phone.isNotEmpty 
                                                  ? appt.phone 
                                                  : appt.email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppConfig.muted,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (appt.phone.isNotEmpty)
                                    Container(
                                      width: 32,
                                      height: 32,
                                      margin: const EdgeInsets.only(left: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        FontAwesomeIcons.phone,
                                        size: 12,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                ],
                              ),
                              // Service-wise breakdown for all bookings with services
                              if (appt.services.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(FontAwesomeIcons.listCheck, 
                                              size: 12, color: theme.color),
                                          const SizedBox(width: 6),
                                          Text(
                                            appt.services.length == 1 
                                                ? 'Service Details' 
                                                : 'Services (${appt.services.length})',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: theme.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...appt.services.map((svc) => Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(colors: theme.gradient),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Center(
                                                child: Icon(FontAwesomeIcons.scissors, 
                                                    color: Colors.white, size: 12),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    svc.name,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppConfig.text,
                                                    ),
                                                  ),
                                                  if (svc.staffName.isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Row(
                                                        children: [
                                                          Icon(FontAwesomeIcons.user, 
                                                              size: 10, color: AppConfig.muted),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            svc.staffName,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: AppConfig.muted,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (svc.staffName.isEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Row(
                                                        children: [
                                                          Icon(FontAwesomeIcons.userSlash, 
                                                              size: 10, color: Colors.orange),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Unassigned',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.orange.shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'AU\$${svc.price.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green.shade700,
                                                  ),
                                                ),
                                                if (svc.duration > 0)
                                                  Text(
                                                    '${svc.duration} min',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppConfig.muted,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                              ] else if (appt.staffName.isNotEmpty) ...[
                                // Fallback for bookings without services array - just show staff
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        FontAwesomeIcons.userCheck,
                                        size: 11,
                                        color: theme.color,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        appt.staffName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppConfig.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Bottom info bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppConfig.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoItem(FontAwesomeIcons.clock, appt.time, theme.color),
                      if (!isOwner)
                        _infoItem(FontAwesomeIcons.user, appt.client, theme.color),
                      if (isOwner && appt.staffName.isEmpty)
                        _infoItem(FontAwesomeIcons.userSlash, 'Unassigned', Colors.orange),
                      _infoItem(FontAwesomeIcons.locationDot, appt.room, theme.color),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppConfig.muted.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(color: AppConfig.muted)),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(fontSize: 13, color: AppConfig.muted)),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppConfig.muted)),
      ],
    );
  }

  Widget _iconButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppConfig.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(icon, size: 16, color: AppConfig.text)),
    );
  }

  BoxDecoration _softShadowDecoration() {
    return BoxDecoration(
      color: AppConfig.card,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 25,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  BranchTheme _resolveBranchTheme(String? branchName) {
    if (branchName != null && AppConfig.branches.containsKey(branchName)) {
      return AppConfig.branches[branchName]!;
    }
    // Fallback theme if branch is unknown or represents multiple branches
    return BranchTheme(
      color: AppConfig.primary,
      lightBg: AppConfig.background,
      gradient: const [AppConfig.primary, AppConfig.accent],
    );
  }
}
