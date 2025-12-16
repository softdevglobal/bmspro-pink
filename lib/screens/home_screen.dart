import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/pink_bottom_nav.dart';
import 'calender_screen.dart';
import 'report_screen.dart';
import 'profile_screen.dart';
import 'notifications_page.dart';
import 'all_appointments_page.dart';
import 'appointment_details_page.dart';
import 'clients_screen.dart';
import 'walk_in_booking_page.dart';
import 'appointment_requests_page.dart';
import 'admin_dashboard.dart';
import 'branch_admin_dashboard.dart';
import 'owner_bookings_page.dart';
import 'more_page.dart';

// --- 1. Theme & Colors (Matching Tailwind Config) ---
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

// Default bottom navigation icons (staff / branch admin)
const List<IconData> kDefaultNavIcons = <IconData>[
  Icons.home_rounded,
  Icons.calendar_month_rounded,
  Icons.groups_rounded,
  Icons.bar_chart_rounded,
  Icons.person_rounded,
];

// Salon owner navigation: Home, Calendar, Bookings, Clients, More
const List<IconData> kOwnerNavIcons = <IconData>[
  Icons.home_rounded,
  Icons.calendar_month_rounded,
  Icons.calendar_today_rounded, // Bookings (3rd)
  Icons.groups_rounded,
  Icons.more_horiz_rounded, // More (5th)
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum ClockStatus { out, clockedIn, onBreak }

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  ClockStatus _status = ClockStatus.out;
  String? _selectedBranch;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _navIndex = 0;
  // Work timer (shows elapsed time after clocking in)
  Timer? _workTimer;
  int _workedSeconds = 0;
  bool _timerRunning = false;

  // Role state
  String? _userRole;
  String? _branchName; // Store branch name if available
  String? _userName; // Store user's name
  String? _branchId;
  String? _ownerUid;
  String? _photoUrl; // Store user's profile photo URL
  bool _isLoadingRole = true;
  
  // Today's appointments
  List<Map<String, dynamic>> _todayAppointments = [];
  bool _isLoadingAppointments = true;
  
  // Unread notifications count
  int _unreadNotificationCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationsSub;
  
  // Pending appointment requests count (for staff)
  int _pendingRequestsCount = 0;
  StreamSubscription<QuerySnapshot>? _pendingRequestsSub;

  @override
  void initState() {
    super.initState();
    // Setup Pulse Animation for the "Clock In" button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchUserRole();
    _listenToUnreadNotifications();
    _listenToPendingRequests();
  }

  /// Listen to unread notifications for the current staff
  void _listenToUnreadNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notificationsSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('staffUid', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = snapshot.docs.length;
        });
      }
    }, onError: (e) {
      debugPrint('Error listening to notifications: $e');
    });
  }

  /// Listen to pending appointment requests assigned to this staff
  void _listenToPendingRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Wait for ownerUid to be available
    await Future.delayed(const Duration(milliseconds: 500));
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
        
        // Check if assigned to current user (check both staffId and staffAuthUid)
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

  Future<void> _fetchUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Use real-time listener so profile updates are reflected immediately
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((doc) {
          if (!mounted) return;
          
          if (doc.exists) {
            final data = doc.data();
            
            // Get name from various possible fields
            String? fetchedName;
            if (data?['displayName'] != null && data!['displayName'].toString().isNotEmpty) {
              fetchedName = data['displayName'].toString();
            } else if (data?['firstName'] != null && data!['firstName'].toString().isNotEmpty) {
              final firstName = data['firstName'].toString();
              final lastName = data['lastName']?.toString() ?? '';
              fetchedName = '$firstName $lastName'.trim();
            } else if (data?['name'] != null && data!['name'].toString().isNotEmpty) {
              fetchedName = data['name'].toString();
            } else if (data?['fullName'] != null && data!['fullName'].toString().isNotEmpty) {
              fetchedName = data['fullName'].toString();
            } else if (user.displayName != null && user.displayName!.isNotEmpty) {
              fetchedName = user.displayName;
            } else if (user.email != null) {
              // Use email prefix as fallback
              fetchedName = user.email!.split('@').first;
            }
            
            // Get photo URL from various possible fields
            String? photoUrl;
            if (data?['photoURL'] != null && data!['photoURL'].toString().isNotEmpty) {
              photoUrl = data['photoURL'].toString();
            } else if (data?['avatarUrl'] != null && data!['avatarUrl'].toString().isNotEmpty) {
              photoUrl = data['avatarUrl'].toString();
            } else if (data?['avatar'] != null && data!['avatar'].toString().startsWith('http')) {
              photoUrl = data['avatar'].toString();
            } else if (user.photoURL != null && user.photoURL!.isNotEmpty) {
              photoUrl = user.photoURL;
            }

            final previousRole = _userRole;
            
            setState(() {
              // Trim and normalize the role to ensure proper comparison
              final rawRole = data?['role'];
              _userRole = rawRole != null ? rawRole.toString().trim() : null;
              // Try to find a branch name or branch field
              _branchName = data?['branchName'] ?? data?['branch'];
              _userName = fetchedName ?? 'Staff';
              _branchId = data?['branchId'];
              _ownerUid = data?['ownerUid'] ?? user.uid;
              _photoUrl = photoUrl;
              _isLoadingRole = false;
            });
            
            // Fetch today's appointments for staff (only once on initial load)
            if (previousRole == null && _userRole != 'salon_owner' && _userRole != 'salon_branch_admin') {
              _fetchTodayAppointments();
            }
          } else {
            // User document doesn't exist, try to get name from Firebase Auth
            setState(() {
              _userName = user.displayName ?? user.email?.split('@').first ?? 'Staff';
              _photoUrl = user.photoURL;
              _ownerUid = user.uid;
              _isLoadingRole = false;
            });
          }
        }, onError: (e) {
          debugPrint('Error listening to user document: $e');
          if (mounted) setState(() => _isLoadingRole = false);
        });
      } else {
        if (mounted) setState(() => _isLoadingRole = false);
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  Future<void> _fetchTodayAppointments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingAppointments = false);
        return;
      }

      // Get today's date in YYYY-MM-DD format
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      debugPrint('Fetching appointments for date: $todayStr, ownerUid: $_ownerUid, staffId: ${user.uid}');

      // Build query - if ownerUid is available, use it; otherwise query by staffId
      Query<Map<String, dynamic>> bookingsQuery;
      
      if (_ownerUid != null && _ownerUid!.isNotEmpty) {
        // Query by ownerUid and date
        bookingsQuery = FirebaseFirestore.instance
            .collection('bookings')
            .where('ownerUid', isEqualTo: _ownerUid)
            .where('date', isEqualTo: todayStr);
      } else {
        // Fallback: Query by staffId directly
        bookingsQuery = FirebaseFirestore.instance
            .collection('bookings')
            .where('staffId', isEqualTo: user.uid)
            .where('date', isEqualTo: todayStr);
      }

      // Listen to bookings
      bookingsQuery.snapshots().listen((snap) {
        final List<Map<String, dynamic>> appointments = [];
        
        debugPrint('Found ${snap.docs.length} bookings for today');
        
        for (final doc in snap.docs) {
          final data = doc.data();
          
          // Check if this booking is assigned to the current staff
          bool isAssigned = false;
          String? serviceName;
          String? duration;
          
          // Check staffId and staffAuthUid at booking level
          final bookingStaffId = data['staffId']?.toString();
          final bookingStaffAuthUid = data['staffAuthUid']?.toString();
          if (bookingStaffId == user.uid || bookingStaffAuthUid == user.uid) {
            isAssigned = true;
            debugPrint('Booking ${doc.id} assigned via staffId');
          }
          
          // Check services array for staff assignment (check both staffId and staffAuthUid)
          if (data['services'] is List) {
            for (final service in (data['services'] as List)) {
              if (service is Map) {
                final serviceStaffId = service['staffId']?.toString();
                final serviceStaffAuthUid = service['staffAuthUid']?.toString();
                if (serviceStaffId == user.uid || serviceStaffAuthUid == user.uid) {
                  isAssigned = true;
                  serviceName ??= service['name']?.toString() ?? service['serviceName']?.toString();
                  duration ??= service['duration']?.toString();
                  debugPrint('Booking ${doc.id} assigned via service staffId');
                }
              }
            }
          }
          
          // If we queried by staffId directly, it's assigned
          if (_ownerUid == null || _ownerUid!.isEmpty) {
            isAssigned = true;
          }
          
          if (!isAssigned) continue;
          
          // Get service name from various possible fields
          if (serviceName == null || serviceName.isEmpty) {
            if (data['services'] is List && (data['services'] as List).isNotEmpty) {
              final firstService = (data['services'] as List).first;
              if (firstService is Map) {
                serviceName = firstService['name']?.toString() ?? firstService['serviceName']?.toString();
                duration = firstService['duration']?.toString();
              }
            }
          }
          serviceName ??= data['serviceName']?.toString() ?? data['service']?.toString() ?? 'Service';
          duration ??= data['duration']?.toString() ?? '';
          
          final time = data['time']?.toString() ?? data['startTime']?.toString() ?? '';
          final status = data['status']?.toString() ?? 'pending';
          
          appointments.add({
            'id': doc.id,
            'serviceName': serviceName,
            'duration': duration,
            'time': time,
            'status': status,
            'client': data['client']?.toString() ?? data['clientName']?.toString() ?? 'Client',
            'data': data,
          });
        }
        
        // Sort by time
        appointments.sort((a, b) {
          final timeA = a['time'] ?? '';
          final timeB = b['time'] ?? '';
          return timeA.compareTo(timeB);
        });
        
        debugPrint('Processed ${appointments.length} appointments assigned to this staff');
        
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

  @override
  void dispose() {
    _pulseController.dispose();
    _workTimer?.cancel();
    _notificationsSub?.cancel();
    _pendingRequestsSub?.cancel();
    super.dispose();
  }

  void _handleClockAction() {
    if (_status == ClockStatus.out) {
      // Open Branch Modal
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BranchSelectionDialog(
          onBranchSelected: (branch) {
            Navigator.pop(context);
            _startLoading(() {
              setState(() {
                _selectedBranch = branch;
                _status = ClockStatus.clockedIn;
              });
              _resetWorkTimer();
              _startWorkTimer();
            });
          },
        ),
      );
    } else if (_status == ClockStatus.clockedIn) {
      // Clock Out
      _startLoading(() {
        setState(() {
          _status = ClockStatus.out;
          _selectedBranch = null;
        });
        _resetWorkTimer();
      });
    }
  }

  void _handleBreakAction() {
    _startLoading(() {
      final next = _status == ClockStatus.clockedIn
          ? ClockStatus.onBreak
          : ClockStatus.clockedIn;
      setState(() {
        _status = next;
      });
      if (next == ClockStatus.onBreak) {
        _pauseWorkTimer();
      } else if (next == ClockStatus.clockedIn) {
        _startWorkTimer();
      }
    });
  }

  // Simulate network/processing delay
  void _startLoading(VoidCallback onComplete) {
    // Here you would add sound effects logic
    Future.delayed(const Duration(seconds: 1), onComplete);
  }

  // --- Work Timer Helpers ---
  void _startWorkTimer() {
    if (_timerRunning) return;
    _timerRunning = true;
    _workTimer?.cancel();
    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_status == ClockStatus.clockedIn) {
        setState(() {
          _workedSeconds += 1;
        });
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
    });
  }

  String _formatElapsed(int totalSeconds) {
    final hrs = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final mins = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hrs:$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final bool isOwnerOrBranchAdmin = _userRole == 'salon_owner' || _userRole == 'salon_branch_admin';
    final List<IconData> icons = isOwnerOrBranchAdmin ? kOwnerNavIcons : kDefaultNavIcons;

    return Scaffold(
      body: _navIndex == 0
          ? _buildHomeTab()
          : _buildTabBody(),
      bottomNavigationBar: PinkBottomNav(
        currentIndex: _navIndex,
        onChanged: (index) => setState(() => _navIndex = index),
        icons: icons,
      ),
    );
  }

  Widget _buildHomeTab() {
    // Check if user is admin or owner
    if (_userRole == 'salon_owner') {
      return AdminDashboard(
        role: _userRole!,
        branchName: _branchName,
      );
    } else if (_userRole == 'salon_branch_admin') {
      return BranchAdminDashboard(
        branchName: _branchName ?? 'Branch',
      );
    }
    // Default to Staff Dashboard
    return _buildStaffDashboard();
  }

  Widget _buildStaffDashboard() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            // Show pending requests alert if there are any
            if (_pendingRequestsCount > 0) ...[
              _buildPendingRequestsAlert(),
              const SizedBox(height: 24),
            ],
            _buildStatusCard(),
            const SizedBox(height: 24),
            _buildAppointmentsSection(),
            const SizedBox(height: 24),
            _buildCreateBookingSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequestsAlert() {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AppointmentRequestsPage()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade400,
              Colors.orange.shade600,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      FontAwesomeIcons.userClock,
                      color: Colors.white,
                      size: 24,
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.orange.shade600, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '$_pendingRequestsCount',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Requests',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_pendingRequestsCount appointment${_pendingRequestsCount == 1 ? '' : 's'} awaiting your approval',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  FontAwesomeIcons.chevronRight,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    final bool isOwnerOrBranchAdmin = _userRole == 'salon_owner' || _userRole == 'salon_branch_admin';

    if (isOwnerOrBranchAdmin) {
      // For salon owners and branch admins: 3rd tab is Bookings, 5th is More
      switch (_navIndex) {
        case 1:
          return const CalenderScreen();
        case 2:
          return const OwnerBookingsPage(); // Booking page (3rd)
        case 3:
          return const ClientsScreen();
        case 4:
          return const MorePage(); // More page (5th)
        default:
          return const SizedBox.shrink();
      }
    } else {
      // Default mapping for staff (includes Profile tab)
      switch (_navIndex) {
        case 1:
          return const CalenderScreen();
        case 2:
          return const ClientsScreen();
        case 3:
          return const ReportScreen();
        case 4:
          return const ProfileScreen();
        default:
          return const SizedBox.shrink();
      }
    }
  }

  // --- UI Components ---
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatDate(DateTime date) {
    const weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${weekDays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  Widget _buildHeader() {
    final displayName = _userName ?? 'Staff';
    // Capitalize first letter of each word
    final formattedName = displayName.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    final firstName = formattedName.split(' ').first;
    final initials = _getInitials(displayName);
    final today = DateTime.now();
    final hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasPhoto ? null : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary.withOpacity(0.2), AppColors.accent.withOpacity(0.2)],
                ),
                image: hasPhoto
                    ? DecorationImage(
                        image: NetworkImage(_photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.08),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: hasPhoto
                  ? null
                  : Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi $firstName',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  _formatDate(today),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(FontAwesomeIcons.bell,
                    color: AppColors.muted, size: 24),
              ),
              // Only show the notification dot when there are unread notifications
              if (_unreadNotificationCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildStatusCard() {
    IconData icon;
    Color iconColor;
    Color iconBg;
    String title;
    String subtitle;
    Widget mainButton;
    Widget? secondaryButton;

    switch (_status) {
      case ClockStatus.out:
        icon = FontAwesomeIcons.clock;
        iconColor = Colors.red;
        iconBg = Colors.red.shade100;
        title = 'You are: CLOCKED OUT';
        subtitle = 'Ready to start your day?';

        mainButton = ScaleTransition(
          scale: _pulseAnimation,
          child: _GradientButton(
            text: 'Clock In',
            icon: FontAwesomeIcons.play,
            onPressed: _handleClockAction,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
            ),
          ),
        );
        break;

      case ClockStatus.clockedIn:
        icon = FontAwesomeIcons.check;
        iconColor = Colors.green;
        iconBg = Colors.green.shade100;
        title = 'Clocked In: $_selectedBranch';
        subtitle = "You're on duty!";

        mainButton = _GradientButton(
          text: 'Clock Out',
          icon: FontAwesomeIcons.stop,
          onPressed: _handleClockAction,
          gradient: LinearGradient(
              colors: [Colors.red.shade500, Colors.red.shade700]),
        );

        secondaryButton = _GradientButton(
          text: 'Take Break',
          icon: FontAwesomeIcons.mugHot,
          onPressed: _handleBreakAction,
          gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.orange.shade600]),
          marginTop: 12,
        );
        break;

      case ClockStatus.onBreak:
        icon = FontAwesomeIcons.mugHot;
        iconColor = Colors.orange;
        iconBg = Colors.orange.shade100;
        title = 'On Break';
        subtitle = 'Enjoy your rest!';

        mainButton = _GradientButton(
          text: 'Start Again',
          icon: FontAwesomeIcons.play,
          onPressed: _handleBreakAction,
          gradient: LinearGradient(
              colors: [Colors.green.shade500, Colors.green.shade700]),
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Icon(icon, color: iconColor, size: 28)),
          ),
          const SizedBox(height: 0),
          Text(
            title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          if (_status != ClockStatus.out) ...[
            const SizedBox(height: 8),
            _buildTimerChip(paused: _status == ClockStatus.onBreak),
          ],
          const SizedBox(height: 16),
          mainButton,
          if (secondaryButton != null) secondaryButton,
        ],
      ),
    );
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
            style: GoogleFonts.shareTechMono(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
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

  Widget _buildAppointmentsSection() {
    // Get pending/confirmed appointments
    final upcomingAppointments = _todayAppointments.where((a) {
      final status = (a['status'] ?? '').toString().toLowerCase();
      return status == 'pending' || status == 'confirmed';
    }).toList();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Appointments",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isLoadingAppointments
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('${upcomingAppointments.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
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
                    'Your schedule is clear!',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          else
            ...upcomingAppointments.asMap().entries.map((entry) {
              final index = entry.key;
              final appointment = entry.value;
              final serviceName = appointment['serviceName'] ?? 'Service';
              final duration = appointment['duration'];
              final time = appointment['time'] ?? '';
              final displayTitle = duration != null && duration.isNotEmpty 
                  ? '$serviceName ${duration}min' 
                  : serviceName;
              
              // Get icon and colors based on service name
              final iconData = _getServiceIcon(serviceName);
              final colors = _getServiceColors(index);
              
              return _buildAppointmentItem(
                displayTitle,
                _formatTime(time),
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
                  MaterialPageRoute(
                      builder: (_) => const AllAppointmentsPage()),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('View All Appointments',
                  style: TextStyle(color: AppColors.primary)),
            ),
          )
        ],
      ),
    );
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

  Widget _buildAppointmentItem(
    String title,
    String time,
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
              child: Center(child: Icon(icon, color: Colors.white, size: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                  Row(
                    children: [
                      Text(time,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
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
                child: const Text('Next',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateBookingSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create a New Booking',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a date and time, then assign a client.',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          _GradientButton(
            text: 'Create Booking',
            icon: FontAwesomeIcons.calendarPlus,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalkInBookingPage()),
              );
            },
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, List<Color> colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
              child: Center(child: Icon(icon, color: Colors.white, size: 20)),
            ),
            Text(label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// --- 3. Branch Selection Modal ---
class BranchSelectionDialog extends StatefulWidget {
  final Function(String) onBranchSelected;
  const BranchSelectionDialog({super.key, required this.onBranchSelected});

  @override
  State<BranchSelectionDialog> createState() => _BranchSelectionDialogState();
}

class _BranchSelectionDialogState extends State<BranchSelectionDialog> {
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = true;
  String? _scheduledBranchName;
  String? _scheduledBranchId;
  
  // Color palette for branches
  final List<List<Color>> _colorPalette = [
    [Colors.purple.shade400, Colors.purple.shade600],
    [Colors.blue.shade400, Colors.blue.shade600],
    [Colors.green.shade400, Colors.green.shade600],
    [Colors.orange.shade400, Colors.orange.shade600],
    [Colors.pink.shade400, Colors.pink.shade600],
    [Colors.teal.shade400, Colors.teal.shade600],
    [Colors.indigo.shade400, Colors.indigo.shade600],
    [Colors.red.shade400, Colors.red.shade600],
  ];

  @override
  void initState() {
    super.initState();
    _loadBranchesAndSchedule();
  }

  String _getTodayWeekday() {
    const weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekDays[DateTime.now().weekday - 1];
  }

  String _formatDate(DateTime date) {
    const weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${weekDays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _loadBranchesAndSchedule() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get user document to find ownerUid and schedule
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String? ownerUid;
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        ownerUid = userData['ownerUid']?.toString() ?? user.uid;
        
        // Check today's schedule
        final todayWeekday = _getTodayWeekday();
        final schedule = userData['schedule'];
        if (schedule is Map && schedule[todayWeekday] != null) {
          final todaySchedule = schedule[todayWeekday];
          if (todaySchedule is Map) {
            _scheduledBranchName = todaySchedule['branchName']?.toString();
            _scheduledBranchId = todaySchedule['branchId']?.toString();
          }
        }
        
        // Also check weeklySchedule format
        final weeklySchedule = userData['weeklySchedule'];
        if (weeklySchedule is Map && weeklySchedule[todayWeekday] != null) {
          final todaySchedule = weeklySchedule[todayWeekday];
          if (todaySchedule is Map) {
            _scheduledBranchName ??= todaySchedule['branchName']?.toString();
            _scheduledBranchId ??= todaySchedule['branchId']?.toString();
          }
        }
      }

      // Fetch branches for this owner
      if (ownerUid != null && ownerUid.isNotEmpty) {
        final branchesSnap = await FirebaseFirestore.instance
            .collection('branches')
            .where('ownerUid', isEqualTo: ownerUid)
            .get();

        final branches = branchesSnap.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name']?.toString() ?? data['branchName']?.toString() ?? 'Branch',
            'address': data['address']?.toString() ?? '',
          };
        }).toList();

        if (mounted) {
          setState(() {
            _branches = branches;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading branches: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                  child: Icon(FontAwesomeIcons.locationDot,
                      color: Colors.white, size: 28)),
            ),
            const Text(
              'Select Your Branch',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text),
            ),
            const SizedBox(height: 4),
            // Today's date
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDate(today),
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 8),
            // Scheduled branch info
            if (_scheduledBranchName != null && _scheduledBranchName!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.1), AppColors.accent.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(FontAwesomeIcons.calendarCheck, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Today you work at $_scheduledBranchName',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const Text(
                "Choose the location you're clocking in at",
                style: TextStyle(fontSize: 14, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            // Branches list
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else if (_branches.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(FontAwesomeIcons.building, size: 32, color: AppColors.muted.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No branches found',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children: _branches.asMap().entries.map((entry) {
                      final index = entry.key;
                      final branch = entry.value;
                      final isScheduled = branch['id'] == _scheduledBranchId || 
                                         branch['name'] == _scheduledBranchName;
                      return _buildBranchOption(
                        branch['name'] ?? 'Branch',
                        branch['id'] ?? '',
                        _colorPalette[index % _colorPalette.length],
                        isScheduled: isScheduled,
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchOption(String name, String branchId, List<Color> colors, {bool isScheduled = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => widget.onBranchSelected(name),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isScheduled ? AppColors.primary.withOpacity(0.08) : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: isScheduled ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Icon(FontAwesomeIcons.building,
                        color: Colors.white, size: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                    if (isScheduled)
                      const Text(
                        'Scheduled today',
                        style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
              if (isScheduled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(FontAwesomeIcons.check, size: 10, color: Colors.white),
                )
              else
                const Icon(FontAwesomeIcons.chevronRight,
                    size: 16, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 4. Helper Widgets ---
class _GradientButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Gradient gradient;
  final double marginTop;

  const _GradientButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    required this.gradient,
    this.marginTop = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: marginTop),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
