import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart' as profile_screen;
import 'appointment_requests_page.dart';
import 'all_appointments_page.dart';
import 'appointment_details_page.dart';
import 'staff_check_in_page.dart';
import '../services/staff_check_in_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'package:geolocator/geolocator.dart';

enum ClockStatus { out, clockedIn, onBreak }

class AppColors {
  static const primary = Color(0xFFFF2D8F);
  static const primaryDark = Color(0xFFD81F75);
  static const accent = Color(0xFFFF6FB5);
  static const background = Color(0xFFFFF5FA);
  static const card = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF9E9E9E);
  static const border = Color(0xFFF2D2E9);
  static const green = Color(0xFF10B981);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFF8B5CF6);
  static const yellow = Color(0xFFFFD700);
  static const orange = Color(0xFFF97316);
}

class BranchAdminDashboard extends StatefulWidget {
  final String branchName;

  const BranchAdminDashboard({super.key, required this.branchName});

  @override
  State<BranchAdminDashboard> createState() => _BranchAdminDashboardState();
}

class _BranchAdminDashboardState extends State<BranchAdminDashboard> with TickerProviderStateMixin {
  bool _loading = true;
  String? _branchId;
  String? _ownerUid;
  
  // Pending approval requests
  int _pendingRequestsCount = 0;
  StreamSubscription<QuerySnapshot>? _pendingRequestsSub;

  // Clock In/Out state
  ClockStatus _clockStatus = ClockStatus.out;
  Timer? _workTimer;
  int _workedSeconds = 0;
  bool _timerRunning = false;
  DateTime? _checkInTime; // Store the actual check-in time to prevent recalculation issues
  String? _selectedBranch;
  String? _activeCheckInId; // Store check-in ID for break tracking
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Location monitoring timer for auto check-out
  Timer? _locationMonitorTimer;

  // KPI Data
  double _totalRevenue = 0;
  double _lastMonthRevenue = 0;
  int _totalBookings = 0;
  int _completedBookings = 0;
  int _totalClients = 0;
  int _returningClients = 0;
  
  // Staff data
  List<Map<String, dynamic>> _staffPerformance = [];
  
  // Service breakdown
  Map<String, double> _serviceRevenue = {};
  
  // Revenue by day (last 30 days)
  List<double> _dailyRevenue = [];
  
  // Today's appointments
  List<Map<String, dynamic>> _todayAppointments = [];
  bool _isLoadingAppointments = true;

  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation for clock in button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _loadData();
    _listenToPendingRequests();
    _fetchTodayAppointments();
    _refreshCheckInStatus(); // Load current check-in status
    
    // Set up notification service for on-screen notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().setContext(context);
      NotificationService().listenToNotifications();
    });
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _workTimer?.cancel();
    _locationMonitorTimer?.cancel();
    _pendingRequestsSub?.cancel();
    NotificationService().dispose();
    super.dispose();
  }
  
  // Clock in/out handlers
  void _handleClockAction() async {
    if (_clockStatus == ClockStatus.out) {
      // Navigate to location-based check-in page
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StaffCheckInPage()),
      );
      // Refresh check-in status after returning
      _refreshCheckInStatus();
    } else if (_clockStatus == ClockStatus.clockedIn) {
      // Navigate to check-in page for check-out
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StaffCheckInPage()),
      );
      // Refresh check-in status after returning
      _refreshCheckInStatus();
    }
  }

  Future<void> _refreshCheckInStatus() async {
    final activeCheckIn = await StaffCheckInService.getActiveCheckIn();
    if (mounted) {
      setState(() {
        if (activeCheckIn != null) {
          _clockStatus = ClockStatus.clockedIn;
          _selectedBranch = activeCheckIn.branchName;
          _activeCheckInId = activeCheckIn.id;
          
          // Use workingSeconds from the record (which excludes breaks)
          final newCheckInTime = activeCheckIn.checkInTime;
          if (_checkInTime == null || 
              _checkInTime!.millisecondsSinceEpoch != newCheckInTime.millisecondsSinceEpoch ||
              !_timerRunning) {
            _checkInTime = newCheckInTime;
            // Use workingSeconds from the record which already excludes breaks
            _workedSeconds = activeCheckIn.workingSeconds;
            _startWorkTimer();
          }
          
          // Start location monitoring for auto check-out
          _startLocationMonitoring();
        } else {
          _clockStatus = ClockStatus.out;
          _selectedBranch = null;
          _checkInTime = null;
          _activeCheckInId = null;
          _resetWorkTimer();
          _stopLocationMonitoring();
        }
      });
    }
  }
  
  /// Start periodic location monitoring to auto check-out when radius is exceeded
  void _startLocationMonitoring() {
    _stopLocationMonitoring(); // Stop any existing timer
    
    // Check location every 60 seconds (1 minute)
    _locationMonitorTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      if (_activeCheckInId == null || _clockStatus != ClockStatus.clockedIn) {
        _stopLocationMonitoring();
        return;
      }
      
      try {
        // Get current location
        final position = await LocationService.getCurrentLocation();
        if (position == null) {
          return; // Could not get location, skip this check
        }
        
        // Check if still within radius and auto check-out if exceeded
        final wasAutoCheckedOut = await StaffCheckInService.autoCheckOutIfExceededRadius(
          checkInId: _activeCheckInId!,
          currentLatitude: position.latitude,
          currentLongitude: position.longitude,
        );
        
        if (wasAutoCheckedOut && mounted) {
          // Show notification to user
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have been automatically checked out for exceeding the branch radius.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          
          // Refresh check-in status
          _refreshCheckInStatus();
        }
      } catch (e) {
        debugPrint('Error in location monitoring: $e');
      }
    });
  }
  
  /// Stop location monitoring
  void _stopLocationMonitoring() {
    _locationMonitorTimer?.cancel();
    _locationMonitorTimer = null;
  }
  
  void _handleBreakAction() async {
    print('Break button clicked. Current status: $_clockStatus');
    
    // Get check-in ID if not already set
    String? checkInId = _activeCheckInId;
    if (checkInId == null) {
      print('Check-in ID not set, fetching active check-in...');
      final activeCheckIn = await StaffCheckInService.getActiveCheckIn();
      if (activeCheckIn == null || activeCheckIn.id == null) {
        print('No active check-in found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active check-in found. Please check in first.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      checkInId = activeCheckIn.id;
      print('Found check-in ID: $checkInId');
      if (mounted) {
        setState(() {
          _activeCheckInId = checkInId;
        });
      }
    } else {
      print('Using existing check-in ID: $checkInId');
    }
    
    final next = _clockStatus == ClockStatus.clockedIn
        ? ClockStatus.onBreak
        : ClockStatus.clockedIn;
    
    print('Next status will be: $next');
    
    if (next == ClockStatus.onBreak) {
      // Start break - record in Firestore
      print('Starting break...');
      final success = await StaffCheckInService.startBreak(checkInId!);
      print('Start break result: $success');
      if (success && mounted) {
        setState(() {
          _clockStatus = ClockStatus.onBreak;
        });
        _pauseWorkTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Break started'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start break. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (next == ClockStatus.clockedIn) {
      // End break - record in Firestore
      print('Ending break...');
      final success = await StaffCheckInService.endBreak(checkInId!);
      print('End break result: $success');
      if (success && mounted) {
        setState(() {
          _clockStatus = ClockStatus.clockedIn;
        });
        // Refresh to get updated working seconds (excluding the break)
        _refreshCheckInStatus();
        _startWorkTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Break ended. Back to work!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to end break. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _startWorkTimer() {
    if (_timerRunning) return;
    _timerRunning = true;
    _workTimer?.cancel();
    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_clockStatus == ClockStatus.clockedIn) {
        setState(() => _workedSeconds += 1);
      }
    });
  }
  
  void _pauseWorkTimer() {
    _workTimer?.cancel();
    _timerRunning = false;
  }
  
  void _resetWorkTimer() {
    _pauseWorkTimer();
    setState(() {
      _workedSeconds = 0;
      _checkInTime = null;
    });
  }
  
  String get _formattedWorkTime {
    final hours = _workedSeconds ~/ 3600;
    final minutes = (_workedSeconds % 3600) ~/ 60;
    final seconds = _workedSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatElapsed(int totalSeconds) {
    final hrs = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final mins = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hrs:$mins:$secs';
  }

  Widget _buildTimerChip({required bool paused}) {
    final Gradient gradient = paused
        ? LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600])
        : const LinearGradient(colors: [AppColors.primary, AppColors.accent]);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                paused ? FontAwesomeIcons.pause : FontAwesomeIcons.clock,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatElapsed(_workedSeconds),
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          if (paused) ...[
            const SizedBox(width: 8),
            const Text(
              'Paused',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600),
            ),
          ]
        ],
      ),
    );
  }
  
  /// Listen to pending appointment requests for branch admin approval
  void _listenToPendingRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Wait for data to load to get ownerUid and branchId
    await Future.delayed(const Duration(milliseconds: 800));
    if (_ownerUid == null || _ownerUid!.isEmpty) return;

    // Listen for both AwaitingStaffApproval AND PartiallyApproved statuses
    _pendingRequestsSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerUid', isEqualTo: _ownerUid)
        .where('status', whereIn: ['AwaitingStaffApproval', 'PartiallyApproved'])
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Branch admin sees requests for their branch
        final bookingBranchId = data['branchId']?.toString();
        if (_branchId != null && bookingBranchId != _branchId) continue;
        
        // Check if assigned to current user (branch admin can also be staff)
        bool hasPendingService = false;
        
        // Single service booking
        final bookingStaffId = data['staffId']?.toString();
        final bookingStaffAuthUid = data['staffAuthUid']?.toString();
        if (bookingStaffId == user.uid || bookingStaffAuthUid == user.uid) {
          hasPendingService = true;
        }
        
        // Multi-service booking - check for pending services assigned to this staff
        if (data['services'] is List) {
          for (final service in (data['services'] as List)) {
            if (service is Map) {
              final serviceStaffId = service['staffId']?.toString();
              final serviceStaffAuthUid = service['staffAuthUid']?.toString();
              final approvalStatus = service['approvalStatus']?.toString() ?? 'pending';
              
              // Only count if assigned to this staff AND status is pending
              final isMyService = serviceStaffId == user.uid || serviceStaffAuthUid == user.uid;
              if (isMyService && approvalStatus == 'pending') {
                hasPendingService = true;
                break;
              }
            }
          }
        }
        
        if (hasPendingService) count++;
      }
      
      setState(() {
        _pendingRequestsCount = count;
      });
    }, onError: (e) {
      debugPrint('Error listening to pending requests: $e');
    });
  }

  Future<void> _fetchTodayAppointments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingAppointments = false);
        return;
      }

      // Wait for data to load to get ownerUid and branchId
      await Future.delayed(const Duration(milliseconds: 800));
      if (_ownerUid == null || _ownerUid!.isEmpty || _branchId == null) {
        setState(() => _isLoadingAppointments = false);
        return;
      }

      // Get today's date in YYYY-MM-DD format
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      debugPrint('Fetching branch admin appointments for date: $todayStr, branchId: $_branchId');

      // Query bookings for this branch today
      FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerUid', isEqualTo: _ownerUid)
          .where('branchId', isEqualTo: _branchId)
          .where('date', isEqualTo: todayStr)
          .snapshots()
          .listen((snap) {
        final List<Map<String, dynamic>> appointments = [];
        
        debugPrint('Found ${snap.docs.length} bookings for today in branch');
        
        for (final doc in snap.docs) {
          final data = doc.data();
          
          // Get service name from various possible fields
          String? serviceName;
          String? duration;
          
          if (data['services'] is List && (data['services'] as List).isNotEmpty) {
            final firstService = (data['services'] as List).first;
            if (firstService is Map) {
              serviceName = firstService['name']?.toString() ?? firstService['serviceName']?.toString();
              duration = firstService['duration']?.toString();
            }
          }
          serviceName ??= data['serviceName']?.toString() ?? data['service']?.toString() ?? 'Service';
          duration ??= data['duration']?.toString() ?? '';
          
          final time = data['time']?.toString() ?? data['startTime']?.toString() ?? '';
          final status = data['status']?.toString() ?? 'pending';
          final staffName = data['staffName']?.toString() ?? 'Unassigned';
          
          appointments.add({
            'id': doc.id,
            'serviceName': serviceName,
            'duration': duration,
            'time': time,
            'status': status,
            'client': data['client']?.toString() ?? data['clientName']?.toString() ?? 'Client',
            'staffName': staffName,
            'data': data,
          });
        }
        
        // Sort by time
        appointments.sort((a, b) {
          final timeA = a['time'] ?? '';
          final timeB = b['time'] ?? '';
          return timeA.compareTo(timeB);
        });
        
        debugPrint('Processed ${appointments.length} appointments for branch');
        
        if (!mounted) return;
        setState(() {
          _todayAppointments = appointments;
          _isLoadingAppointments = false;
        });
      }, onError: (e) {
        debugPrint('Error fetching appointments: $e');
        if (mounted) setState(() => _isLoadingAppointments = false);
      });
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Get user's branch and owner info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() => _loading = false);
        return;
      }

      final userData = userDoc.data()!;
      _branchId = userData['branchId']?.toString();
      _ownerUid = userData['ownerUid']?.toString() ?? user.uid;

      if (_branchId == null || _branchId!.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      // Fetch all bookings for this branch
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final sixtyDaysAgo = now.subtract(const Duration(days: 60));

      final bookingsSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerUid', isEqualTo: _ownerUid)
          .where('branchId', isEqualTo: _branchId)
          .get();

      // Process bookings
      double totalRevenue = 0;
      double lastMonthRevenue = 0;
      int completedBookings = 0;
      Set<String> uniqueClients = {};
      Map<String, int> clientBookingCount = {};
      Map<String, double> serviceRevenue = {};
      Map<String, double> staffRevenue = {};
      Map<String, int> staffBookingCount = {};
      List<double> dailyRevenue = List.filled(30, 0);

      for (var doc in bookingsSnap.docs) {
        final data = doc.data();
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        final status = (data['status'] ?? '').toString().toLowerCase();
        final dateStr = (data['date'] ?? '').toString();
        final client = (data['client'] ?? '').toString();
        final serviceName = (data['serviceName'] ?? '').toString();
        final staffName = (data['staffName'] ?? 'Unassigned').toString();

        // Parse date
        DateTime? bookingDate;
        try {
          if (dateStr.isNotEmpty) {
            bookingDate = DateTime.parse(dateStr);
          }
        } catch (_) {}

        // Count completed bookings
        if (status == 'completed' || status == 'confirmed') {
          completedBookings++;
          totalRevenue += price;

          // Track client
          if (client.isNotEmpty) {
            uniqueClients.add(client.toLowerCase());
            clientBookingCount[client.toLowerCase()] = 
                (clientBookingCount[client.toLowerCase()] ?? 0) + 1;
          }

          // Service revenue
          if (serviceName.isNotEmpty) {
            // Split if multiple services
            for (var svc in serviceName.split(',')) {
              final svcName = svc.trim();
              if (svcName.isNotEmpty) {
                serviceRevenue[svcName] = (serviceRevenue[svcName] ?? 0) + (price / serviceName.split(',').length);
              }
            }
          }

          // Staff performance
          if (staffName.isNotEmpty && staffName != 'Any Available' && staffName != 'Multiple Staff') {
            staffRevenue[staffName] = (staffRevenue[staffName] ?? 0) + price;
            staffBookingCount[staffName] = (staffBookingCount[staffName] ?? 0) + 1;
          }

          // Daily revenue (last 30 days)
          if (bookingDate != null && bookingDate.isAfter(thirtyDaysAgo)) {
            final dayIndex = now.difference(bookingDate).inDays;
            if (dayIndex >= 0 && dayIndex < 30) {
              dailyRevenue[29 - dayIndex] += price;
            }
          }

          // Last month revenue (30-60 days ago)
          if (bookingDate != null && 
              bookingDate.isAfter(sixtyDaysAgo) && 
              bookingDate.isBefore(thirtyDaysAgo)) {
            lastMonthRevenue += price;
          }
        }
      }

      // Calculate returning clients
      int returningClients = clientBookingCount.values.where((c) => c > 1).length;

      // Build staff performance list
      List<Map<String, dynamic>> staffPerformance = [];
      staffRevenue.forEach((name, revenue) {
        staffPerformance.add({
          'name': name,
          'revenue': revenue,
          'bookings': staffBookingCount[name] ?? 0,
        });
      });
      staffPerformance.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

      if (mounted) {
        setState(() {
          _totalRevenue = totalRevenue;
          _lastMonthRevenue = lastMonthRevenue;
          _totalBookings = bookingsSnap.docs.length;
          _completedBookings = completedBookings;
          _totalClients = uniqueClients.length;
          _returningClients = returningClients;
          _serviceRevenue = serviceRevenue;
          _staffPerformance = staffPerformance.take(5).toList();
          _dailyRevenue = dailyRevenue;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  double get _revenueGrowth {
    if (_lastMonthRevenue == 0) return 0;
    return ((_totalRevenue - _lastMonthRevenue) / _lastMonthRevenue) * 100;
  }

  double get _clientRetention {
    if (_totalClients == 0) return 0;
    return (_returningClients / _totalClients) * 100;
  }

  double get _avgTicketValue {
    if (_completedBookings == 0) return 0;
    return _totalRevenue / _completedBookings;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildClockInCard(),
              const SizedBox(height: 24),
              if (_pendingRequestsCount > 0) ...[
                _buildPendingRequestsAlert(),
                const SizedBox(height: 24),
              ],
              _buildAppointmentsSection(),
              const SizedBox(height: 24),
              _buildKpiSection(),
              const SizedBox(height: 24),
              _buildRevenueChartSection(),
              const SizedBox(height: 24),
              _buildServiceBreakdownSection(),
              const SizedBox(height: 24),
              _buildStaffPerformanceSection(),
              const SizedBox(height: 24),
              _buildInsightsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Profile button + Dashboard title
            Expanded(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: AppColors.background,
                            body: const profile_screen.ProfileScreen(
                              showBackButton: true,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.15),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          FontAwesomeIcons.user,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Analytics & insights',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Logged in admin name on the right
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FontAwesomeIcons.userTie, size: 12, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    widget.branchName.isNotEmpty ? '${widget.branchName} Admin' : 'Branch Admin',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingRequestsAlert() {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AppointmentRequestsPage()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade400, Colors.orange.shade500],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  FontAwesomeIcons.bellConcierge,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_pendingRequestsCount Pending Approval${_pendingRequestsCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to review and approve bookings',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                FontAwesomeIcons.chevronRight,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockInCard() {
    IconData icon;
    Color iconColor;
    Color iconBg;
    String title;
    String subtitle;
    Widget mainButton;
    Widget? secondaryButton;

    switch (_clockStatus) {
      case ClockStatus.out:
        icon = FontAwesomeIcons.clock;
        iconColor = Colors.red;
        iconBg = Colors.red.shade100;
        title = 'You are: CLOCKED OUT';
        subtitle = 'Ready to start your shift?';

        mainButton = ScaleTransition(
          scale: _pulseAnimation,
          child: _buildClockButton(
            text: 'Clock In',
            icon: FontAwesomeIcons.play,
            onPressed: _handleClockAction,
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
          ),
        );
        break;

      case ClockStatus.clockedIn:
        icon = FontAwesomeIcons.check;
        iconColor = Colors.green;
        iconBg = Colors.green.shade100;
        title = 'Clocked In: ${_selectedBranch ?? widget.branchName}';
        subtitle = "You're on duty!";

        mainButton = _buildClockButton(
          text: 'Clock Out',
          icon: FontAwesomeIcons.stop,
          onPressed: _handleClockAction,
          gradient: LinearGradient(colors: [Colors.red.shade500, Colors.red.shade700]),
        );

        secondaryButton = _buildClockButton(
          text: 'Take Break',
          icon: FontAwesomeIcons.mugHot,
          onPressed: _handleBreakAction,
          gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.orange.shade600]),
        );
        break;

      case ClockStatus.onBreak:
        icon = FontAwesomeIcons.mugHot;
        iconColor = Colors.orange;
        iconBg = Colors.orange.shade100;
        title = 'On Break';
        subtitle = 'Time worked: $_formattedWorkTime';

        mainButton = _buildClockButton(
          text: 'Resume Work',
          icon: FontAwesomeIcons.play,
          onPressed: _handleBreakAction,
          gradient: LinearGradient(colors: [Colors.green.shade500, Colors.green.shade700]),
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_clockStatus != ClockStatus.out) ...[
            const SizedBox(height: 12),
            _buildTimerChip(paused: _clockStatus == ClockStatus.onBreak),
          ],
          const SizedBox(height: 16),
          mainButton,
          if (secondaryButton != null) ...[
            const SizedBox(height: 8),
            secondaryButton,
          ],
        ],
      ),
    );
  }

  Widget _buildClockButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Gradient gradient,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient).colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  // --- Appointments Section Methods ---
  String _formatTime(String time) {
    if (time.isEmpty) return '';
    
    // If already formatted (contains AM/PM), return as is
    if (time.toUpperCase().contains('AM') || time.toUpperCase().contains('PM')) {
      return time;
    }
    
    // Try to parse HH:mm format
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        return '$hour:$minute $period';
      }
    } catch (_) {}
    
    return time;
  }

  IconData _getServiceIcon(String serviceName) {
    final name = serviceName.toLowerCase();
    if (name.contains('massage') || name.contains('spa')) {
      return FontAwesomeIcons.spa;
    } else if (name.contains('facial') || name.contains('face')) {
      return FontAwesomeIcons.leaf;
    } else if (name.contains('nail') || name.contains('manicure') || name.contains('pedicure')) {
      return FontAwesomeIcons.handSparkles;
    } else if (name.contains('hair') || name.contains('cut') || name.contains('style')) {
      return FontAwesomeIcons.scissors;
    } else if (name.contains('wax') || name.contains('threading')) {
      return FontAwesomeIcons.feather;
    } else if (name.contains('makeup') || name.contains('beauty')) {
      return FontAwesomeIcons.wandMagicSparkles;
    }
    return FontAwesomeIcons.calendarCheck;
  }

  List<Color> _getServiceColors(int index) {
    final colorSets = [
      [Colors.purple.shade400, Colors.purple.shade600],
      [Colors.pink.shade400, Colors.pink.shade600],
      [AppColors.accent, AppColors.primary],
      [Colors.blue.shade400, Colors.blue.shade600],
      [Colors.teal.shade400, Colors.teal.shade600],
      [Colors.orange.shade400, Colors.orange.shade600],
    ];
    return colorSets[index % colorSets.length];
  }

  Widget _buildAppointmentsSection() {
    // Get pending/confirmed appointments
    final upcomingAppointments = _todayAppointments.where((a) {
      final status = (a['status'] ?? '').toString().toLowerCase();
      return status == 'pending' || status == 'confirmed' || status == 'awaitingstaffapproval' || status == 'partiallyapproved';
    }).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(FontAwesomeIcons.calendarDay, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    "Today's Appointments",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isLoadingAppointments
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        '${upcomingAppointments.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              )
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingAppointments)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else if (upcomingAppointments.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    FontAwesomeIcons.calendarCheck,
                    size: 40,
                    color: AppColors.muted.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No appointments today',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your branch schedule is clear!',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          else
            ...upcomingAppointments.take(5).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final appointment = entry.value;
              final serviceName = appointment['serviceName'] ?? 'Service';
              final duration = appointment['duration'];
              final time = appointment['time'] ?? '';
              final staffName = appointment['staffName'] ?? 'Unassigned';
              final displayTitle = duration != null && duration.isNotEmpty 
                  ? '$serviceName ${duration}min' 
                  : serviceName;
              
              // Get icon and colors based on service name
              final iconData = _getServiceIcon(serviceName);
              final colors = _getServiceColors(index);
              
              return _buildAppointmentItem(
                displayTitle,
                _formatTime(time),
                staffName,
                iconData,
                colors,
                isNext: index == 0,
                appointmentData: appointment,
              );
            }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AllAppointmentsPage()),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View All Appointments',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAppointmentItem(
    String title,
    String time,
    String staffName,
    IconData icon,
    List<Color> gradientColors, {
    bool isNext = false,
    Map<String, dynamic>? appointmentData,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppointmentDetailsPage(appointmentData: appointmentData),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
              child: Center(child: Icon(icon, color: Colors.white, size: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        time,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      if (appointmentData != null && appointmentData['client'] != null) ...[
                        const Text(' • ', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        Flexible(
                          child: Text(
                            appointmentData['client'],
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (staffName.isNotEmpty && staffName != 'Unassigned')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(FontAwesomeIcons.userTag, size: 10, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Text(
                            staffName,
                            style: TextStyle(
                              color: AppColors.muted.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (isNext)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSection() {
    final growthPercent = _revenueGrowth;
    final isPositiveGrowth = growthPercent >= 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Total Revenue',
                value: '\$${_totalRevenue.toStringAsFixed(0)}',
                icon: FontAwesomeIcons.dollarSign,
                iconColor: AppColors.green,
                iconBg: AppColors.green.withOpacity(0.1),
                trend: '${isPositiveGrowth ? '+' : ''}${growthPercent.toStringAsFixed(0)}%',
                trendUp: isPositiveGrowth,
                trendColor: isPositiveGrowth ? AppColors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Bookings',
                value: '$_completedBookings',
                icon: FontAwesomeIcons.calendarCheck,
                iconColor: AppColors.purple,
                iconBg: AppColors.purple.withOpacity(0.1),
                subtitle: 'of $_totalBookings total',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Client Retention',
                value: '${_clientRetention.toStringAsFixed(0)}%',
                icon: FontAwesomeIcons.heart,
                iconColor: AppColors.blue,
                iconBg: AppColors.blue.withOpacity(0.1),
                subtitle: '$_returningClients returning',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Avg Ticket Value',
                value: '\$${_avgTicketValue.toStringAsFixed(0)}',
                icon: FontAwesomeIcons.ticket,
                iconColor: AppColors.orange,
                iconBg: AppColors.orange.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    String? trend,
    bool? trendUp,
    Color? trendColor,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trendColor?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: trendColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueChartSection() {
    // Convert daily revenue to chart spots (sample every 5 days for cleaner chart)
    List<FlSpot> spots = [];
    for (int i = 0; i < 7; i++) {
      final dayIndex = i * 4; // 0, 4, 8, 12, 16, 20, 24
      if (dayIndex < _dailyRevenue.length) {
        // Sum revenue for a few days around this point
        double sum = 0;
        for (int j = dayIndex; j < dayIndex + 4 && j < _dailyRevenue.length; j++) {
          sum += _dailyRevenue[j];
        }
        spots.add(FlSpot(i.toDouble(), sum / 100)); // Scale down for chart
      }
    }

    if (spots.isEmpty) {
      spots = [const FlSpot(0, 0), const FlSpot(1, 0)];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FontAwesomeIcons.chartLine, color: AppColors.green, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Revenue Trends (Last 30 Days)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const titles = ['Day 1', '5', '10', '15', '20', '25', '30'];
                        if (value.toInt() >= 0 && value.toInt() < titles.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(titles[value.toInt()], style: const TextStyle(color: AppColors.muted, fontSize: 10)),
                          );
                        }
                        return const Text('');
                      },
                      interval: 1,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.green,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.green.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceBreakdownSection() {
    if (_serviceRevenue.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(FontAwesomeIcons.chartPie, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Revenue by Service Type',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('No service data available', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }

    // Calculate percentages
    final total = _serviceRevenue.values.fold(0.0, (a, b) => a + b);
    final sortedServices = _serviceRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topServices = sortedServices.take(4).toList();

    final colors = [
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
    ];

    List<PieChartSectionData> sections = [];
    List<Widget> legends = [];

    for (int i = 0; i < topServices.length; i++) {
      final entry = topServices[i];
      final percent = (entry.value / total) * 100;
      sections.add(PieChartSectionData(
        color: colors[i % colors.length],
        value: percent,
        title: '${percent.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      legends.add(_buildLegendItem(colors[i % colors.length], entry.key));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FontAwesomeIcons.chartPie, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Revenue by Service Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: legends,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text.length > 15 ? '${text.substring(0, 15)}...' : text,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _buildStaffPerformanceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FontAwesomeIcons.trophy, color: AppColors.yellow, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Top Performing Staff',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_staffPerformance.isEmpty)
            const Text('No staff performance data', style: TextStyle(color: AppColors.muted))
          else
            ...List.generate(_staffPerformance.length, (index) {
              final staff = _staffPerformance[index];
              final isFirst = index == 0;
              return Padding(
                padding: EdgeInsets.only(bottom: index < _staffPerformance.length - 1 ? 12 : 0),
                child: _buildStaffItem(
                  staff['name'],
                  '\$${(staff['revenue'] as double).toStringAsFixed(0)} • ${staff['bookings']} services',
                  index + 1,
                  isFirst ? Colors.yellow.shade50 : Colors.grey.shade50,
                  isFirst ? Colors.yellow.shade100 : Colors.transparent,
                  isFirst ? AppColors.yellow : Colors.grey.shade400,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStaffItem(
      String name, String details, int rank, Color bgColor, Color borderColor, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor == Colors.transparent ? Colors.transparent : borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.text)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.length > 20 ? '${name.substring(0, 20)}...' : name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    details,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    // Generate dynamic insights based on data
    List<Map<String, dynamic>> insights = [];

    // Revenue insight
    if (_revenueGrowth > 0) {
      insights.add({
        'title': 'Revenue Growth',
        'description': '${_revenueGrowth.toStringAsFixed(0)}% increase compared to last month',
        'icon': FontAwesomeIcons.arrowUp,
        'iconColor': Colors.green.shade500,
        'bgColor': Colors.green.shade50,
      });
    } else if (_revenueGrowth < 0) {
      insights.add({
        'title': 'Revenue Decline',
        'description': '${_revenueGrowth.abs().toStringAsFixed(0)}% decrease compared to last month',
        'icon': FontAwesomeIcons.arrowDown,
        'iconColor': Colors.red.shade500,
        'bgColor': Colors.red.shade50,
      });
    }

    // Top service insight
    if (_serviceRevenue.isNotEmpty) {
      final topService = _serviceRevenue.entries.reduce((a, b) => a.value > b.value ? a : b);
      insights.add({
        'title': 'Top Service',
        'description': '${topService.key} generates most revenue',
        'icon': FontAwesomeIcons.star,
        'iconColor': Colors.blue.shade500,
        'bgColor': Colors.blue.shade50,
      });
    }

    // Client retention insight
    if (_clientRetention > 50) {
      insights.add({
        'title': 'Great Retention',
        'description': '${_clientRetention.toStringAsFixed(0)}% of clients are returning customers',
        'icon': FontAwesomeIcons.heart,
        'iconColor': Colors.pink.shade500,
        'bgColor': Colors.pink.shade50,
      });
    } else if (_totalClients > 0) {
      insights.add({
        'title': 'Retention Opportunity',
        'description': 'Consider loyalty programs to increase repeat visits',
        'icon': FontAwesomeIcons.circleExclamation,
        'iconColor': Colors.orange.shade500,
        'bgColor': Colors.orange.shade50,
      });
    }

    if (insights.isEmpty) {
      insights.add({
        'title': 'Getting Started',
        'description': 'Complete more bookings to see insights',
        'icon': FontAwesomeIcons.lightbulb,
        'iconColor': Colors.blue.shade500,
        'bgColor': Colors.blue.shade50,
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FontAwesomeIcons.lightbulb, color: AppColors.blue, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Business Insights',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.asMap().entries.map((entry) {
            final index = entry.key;
            final insight = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index < insights.length - 1 ? 12 : 0),
              child: _buildInsightItem(
                insight['title'],
                insight['description'],
                insight['icon'],
                insight['iconColor'],
                insight['bgColor'],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInsightItem(
      String title, String description, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
