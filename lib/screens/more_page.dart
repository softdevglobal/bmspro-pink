import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'services_page.dart';
import 'staff_management_page.dart';
import 'attendance_page.dart';
import 'branches_page.dart';
import 'salon_settings_page.dart';
import 'audit_logs_page.dart';
import '../widgets/animated_toggle.dart';
import '../services/staff_check_in_service.dart';

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

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (mounted && doc.exists) {
          setState(() {
            _userRole = doc.data()?['role'] as String?;
            _isLoading = false;
          });
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isBranchAdmin => _userRole == 'salon_branch_admin';
  bool get _isSalonOwner => _userRole == 'salon_owner';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            const Text(
              'More',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isBranchAdmin ? 'Manage your branch' : 'Manage your salon settings',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Services Section - Available for all roles
            _buildMenuCard(
              context,
              icon: FontAwesomeIcons.scissors,
              title: 'Services',
              subtitle: _isBranchAdmin ? 'View available services' : 'Manage your salon services',
              gradientColors: [const Color(0xFFEC4899), const Color(0xFFF472B6)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServicesPage()),
                );
              },
            ),
            const SizedBox(height: 16),

            // Staff Section (Expandable) - Only for salon owners
            if (_isSalonOwner) ...[
              _buildExpandableMenuCard(
                context,
                icon: FontAwesomeIcons.users,
                title: 'Staff',
                subtitle: 'Manage staff and attendance',
                gradientColors: [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
                children: [
                  _buildSubMenuItem(
                    context,
                    icon: FontAwesomeIcons.userGear,
                    title: 'Staff Management',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StaffManagementPage()),
                      );
                    },
                  ),
                  _buildSubMenuItem(
                    context,
                    icon: FontAwesomeIcons.clipboardUser,
                    title: 'Attendance',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AttendancePage()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Branches Section - Available for all roles (branch admins see their branch)
            _buildMenuCard(
              context,
              icon: FontAwesomeIcons.building,
              title: _isBranchAdmin ? 'My Branch' : 'Branches',
              subtitle: _isBranchAdmin ? 'View your branch details' : 'Manage your salon locations',
              gradientColors: [const Color(0xFF10B981), const Color(0xFF34D399)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BranchesPage()),
                );
              },
            ),

            // Summary Section - For branch admins
            if (_isBranchAdmin) ...[
              const SizedBox(height: 16),
              _buildMenuCard(
                context,
                icon: FontAwesomeIcons.chartPie,
                title: 'Summary',
                subtitle: 'View your performance & branch reports',
                gradientColors: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BranchAdminSummaryPage()),
                  );
                },
              ),
            ],

            // Summary Section - Only for salon owners
            if (_isSalonOwner) ...[
              const SizedBox(height: 16),
              _buildMenuCard(
                context,
                icon: FontAwesomeIcons.chartPie,
                title: 'Summary',
                subtitle: 'View your performance & reports',
                gradientColors: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MySummaryPage()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildMenuCard(
                context,
                icon: FontAwesomeIcons.clipboardList,
                title: 'Audit Logs',
                subtitle: 'Track all system activities & changes',
                gradientColors: [const Color(0xFF475569), const Color(0xFF64748B)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuditLogsPage()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildMenuCard(
                context,
                icon: FontAwesomeIcons.gear,
                title: 'Salon Settings',
                subtitle: 'Business profile, logo & terms',
                gradientColors: [const Color(0xFF6366F1), const Color(0xFF818CF8)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SalonSettingsPage()),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 20,
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    FontAwesomeIcons.chevronRight,
                    color: AppColors.muted,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
            ),
          ),
          iconColor: AppColors.muted,
          collapsedIconColor: AppColors.muted,
          children: children,
        ),
      ),
    );
  }

  Widget _buildSubMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.only(bottom: 8),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
              ),
              const Icon(
                FontAwesomeIcons.chevronRight,
                color: AppColors.muted,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// OTHER SUB-PAGES
// ============================================================================

class MySummaryPage extends StatefulWidget {
  const MySummaryPage({super.key});

  @override
  State<MySummaryPage> createState() => _MySummaryPageState();
}

class _MySummaryPageState extends State<MySummaryPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft, size: 18, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Tab Selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    _buildTabButton('Day', 0),
                    _buildTabButton('Week', 1),
                    _buildTabButton('Month', 2),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Daily Summary Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF2D8F), Color(0xFFFF6FB5)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF2D8F).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(_getDateString(), style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Stats Grid
              Row(
                children: [
                  Expanded(child: _buildStatCard(FontAwesomeIcons.clock, '7h 45m', 'Hours Worked')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(FontAwesomeIcons.circleCheck, '6', 'Tasks Completed')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatCard(FontAwesomeIcons.dollarSign, '\$85', 'Total Tips')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(FontAwesomeIcons.star, '4.8', 'Rating')),
                ],
              ),
              const SizedBox(height: 20),
              // Notes
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                    SizedBox(height: 8),
                    Text('Great work today! 🌸', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF2D8F) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.muted)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFFF2D8F).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Icon(icon, color: const Color(0xFFFF2D8F), size: 20)),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ),
    );
  }

  String _getDateString() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

// ============================================================================
// BRANCH ADMIN SUMMARY PAGE
// ============================================================================

class BranchAdminSummaryPage extends StatefulWidget {
  const BranchAdminSummaryPage({super.key});

  @override
  State<BranchAdminSummaryPage> createState() => _BranchAdminSummaryPageState();
}

class _BranchAdminSummaryPageState extends State<BranchAdminSummaryPage> {
  bool _showBranchSummary = false; // false = My Summary, true = Branch Summary
  bool _loading = true;

  // My Summary data
  int _myCompletedServices = 0;
  double _myRevenue = 0;
  int _myTotalBookings = 0;
  Map<String, int> _dailyWorkingHours = {}; // Day-wise working hours in seconds
  int _totalWeeklyHours = 0; // Total weekly hours in seconds

  // Branch Summary data
  double _branchRevenue = 0;
  int _branchBookings = 0;
  int _branchStaffCount = 0;
  int _branchCompletedBookings = 0;
  int _branchPendingBookings = 0;
  String _branchName = 'My Branch';

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      // Get user document to find branchId and ownerUid
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() => _loading = false);
        return;
      }

      final userData = userDoc.data()!;
      final branchId = (userData['branchId'] ?? '').toString();
      final ownerUid = (userData['ownerUid'] ?? '').toString();
      
      debugPrint('Branch Admin Summary - branchId: $branchId, ownerUid: $ownerUid');
      
      // Get branch name from branches collection
      String branchNameForMatching = '';
      if (branchId.isNotEmpty) {
        final branchDoc = await FirebaseFirestore.instance
            .collection('branches')
            .doc(branchId)
            .get();
        if (branchDoc.exists) {
          _branchName = (branchDoc.data()?['name'] ?? 'My Branch').toString();
          branchNameForMatching = _branchName.toLowerCase();
          debugPrint('Branch name from DB: $_branchName');
        }
      }
      
      // Also check user document for branchName as fallback
      if (_branchName == 'My Branch') {
        _branchName = (userData['branchName'] ?? 'My Branch').toString();
        branchNameForMatching = _branchName.toLowerCase();
      }

      // Load ALL bookings for the owner (we'll filter by branch)
      final allBookingsQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerUid', isEqualTo: ownerUid)
          .get();
      
      debugPrint('Total bookings for owner: ${allBookingsQuery.docs.length}');

      int myCompleted = 0;
      double myRevenue = 0;
      int myTotal = 0;

      // Load Branch Summary
      double branchRevenue = 0;
      int branchBookings = 0;
      int branchCompleted = 0;
      int branchPending = 0;

      for (final doc in allBookingsQuery.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        final bookingBranchId = (data['branchId'] ?? '').toString();
        
        // ============== MY SUMMARY ==============
        // Check if this booking is assigned to me (staff)
        bool isMyBooking = false;
        double myServiceRevenue = 0;
        
        // Check top-level staffId
        if (data['staffId'] == user.uid || data['staffAuthUid'] == user.uid) {
          isMyBooking = true;
          myServiceRevenue = _getPrice(data['price']);
        }
        
        // Check services array
        if (data['services'] is List) {
          for (final service in (data['services'] as List)) {
            if (service is Map) {
              final svcStaffId = service['staffId']?.toString();
              final svcStaffAuthUid = service['staffAuthUid']?.toString();
              if (svcStaffId == user.uid || svcStaffAuthUid == user.uid) {
                isMyBooking = true;
                myServiceRevenue += _getPrice(service['price']);
              }
            }
          }
        }

        if (isMyBooking) {
          myTotal++;
          if (status == 'completed') {
            myCompleted++;
            myRevenue += myServiceRevenue;
          }
        }
        
        // ============== BRANCH SUMMARY ==============
        // Match by branchId OR by branchName (some bookings might use name)
        final bookingBranchName = (data['branchName'] ?? '').toString().toLowerCase();
        final isBranchMatch = bookingBranchId == branchId || 
                              (branchNameForMatching.isNotEmpty && bookingBranchName == branchNameForMatching);
        
        if (isBranchMatch) {
          branchBookings++;
          
          // Count by status
          if (status == 'completed') {
            branchCompleted++;
          } else if (status == 'pending' || 
                     status.contains('awaiting') || 
                     status.contains('partially')) {
            branchPending++;
          }
          
          // Revenue for completed and confirmed bookings
          if (status == 'completed' || status == 'confirmed') {
            branchRevenue += _getPrice(data['price']);
          }
        }
      }
      
      debugPrint('Branch $branchId: bookings=$branchBookings, completed=$branchCompleted, pending=$branchPending, revenue=$branchRevenue');

      // Count branch staff - get from branch document's staffIds array
      int staffCount = 0;
      
      // The branch document has staffIds array with all assigned staff
      if (branchId.isNotEmpty) {
        final branchDoc = await FirebaseFirestore.instance
            .collection('branches')
            .doc(branchId)
            .get();
        
        if (branchDoc.exists) {
          final branchData = branchDoc.data();
          final staffIds = branchData?['staffIds'];
          if (staffIds is List) {
            staffCount = staffIds.length;
            debugPrint('Staff from branch staffIds: $staffCount');
          }
        }
      }
      
      // If no staffIds in branch, count staff who have this branch in their schedule
      if (staffCount == 0) {
        final usersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('ownerUid', isEqualTo: ownerUid)
            .get();
        
        for (final doc in usersQuery.docs) {
          final data = doc.data();
          final role = (data['role'] ?? '').toString().toLowerCase();
          
          if (role != 'salon_staff' && role != 'salon_branch_admin') continue;
          
          // Check if user's branchId matches
          final userBranchId = (data['branchId'] ?? '').toString();
          if (userBranchId == branchId) {
            staffCount++;
            continue;
          }
          
          // Check weeklySchedule for branch assignment
          final schedule = data['weeklySchedule'];
          if (schedule is Map) {
            for (final daySchedule in schedule.values) {
              if (daySchedule is Map) {
                final scheduleBranchId = daySchedule['branchId']?.toString();
                if (scheduleBranchId == branchId) {
                  staffCount++;
                  break;
                }
              }
            }
          }
        }
      }
      
      debugPrint('Final staff count for branch $branchId: $staffCount');

      // Calculate weekly working hours (day-wise)
      await _calculateWeeklyWorkingHours(user.uid);

      if (!mounted) return;
      setState(() {
        _myCompletedServices = myCompleted;
        _myRevenue = myRevenue;
        _myTotalBookings = myTotal;
        _branchRevenue = branchRevenue;
        _branchBookings = branchBookings;
        _branchStaffCount = staffCount;
        _branchCompletedBookings = branchCompleted;
        _branchPendingBookings = branchPending;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading summary data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }
  
  double _getPrice(dynamic price) {
    if (price == null) return 0;
    if (price is num) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0;
    return 0;
  }

  Future<void> _calculateWeeklyWorkingHours(String userId) async {
    try {
      // Get the start of the current week (Monday)
      final now = DateTime.now();
      final startOfWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final startOfWeekTimestamp = Timestamp.fromDate(startOfWeek);
      
      // Get the end of the current week (Sunday)
      final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      final endOfWeekTimestamp = Timestamp.fromDate(endOfWeek);

      // Query check-ins for this week
      final checkInsQuery = await FirebaseFirestore.instance
          .collection('staff_check_ins')
          .where('staffAuthUid', isEqualTo: userId)
          .where('checkInTime', isGreaterThanOrEqualTo: startOfWeekTimestamp)
          .where('checkInTime', isLessThanOrEqualTo: endOfWeekTimestamp)
          .get();

      // Initialize day-wise map
      final dailyHours = <String, int>{
        'Monday': 0,
        'Tuesday': 0,
        'Wednesday': 0,
        'Thursday': 0,
        'Friday': 0,
        'Saturday': 0,
        'Sunday': 0,
      };

      int totalSeconds = 0;

      for (final doc in checkInsQuery.docs) {
        final checkIn = StaffCheckInRecord.fromFirestore(doc);
        final checkInDate = checkIn.checkInTime;
        final dayName = _getDayName(checkInDate.weekday);
        
        // Calculate working seconds for this check-in
        final workingSeconds = checkIn.workingSeconds;
        dailyHours[dayName] = (dailyHours[dayName] ?? 0) + workingSeconds;
        totalSeconds += workingSeconds;
      }

      if (mounted) {
        setState(() {
          _dailyWorkingHours = dailyHours;
          _totalWeeklyHours = totalSeconds;
        });
      }
    } catch (e) {
      debugPrint('Error calculating weekly working hours: $e');
      if (mounted) {
        setState(() {
          _dailyWorkingHours = {
            'Monday': 0,
            'Tuesday': 0,
            'Wednesday': 0,
            'Thursday': 0,
            'Friday': 0,
            'Saturday': 0,
            'Sunday': 0,
          };
          _totalWeeklyHours = 0;
        });
      }
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Monday';
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '0m';
    }
  }

  Widget _buildWeeklyHoursChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    // Find max hours for scaling
    double maxHours = 0;
    for (final dayName in dayNames) {
      final seconds = _dailyWorkingHours[dayName] ?? 0;
      final hours = seconds / 3600.0;
      if (hours > maxHours) maxHours = hours;
    }
    // Set minimum max to 8 hours for better visualization
    if (maxHours < 8) maxHours = 8;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxHours,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => const Color(0xFF3B82F6),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final dayName = dayNames[group.x.toInt()];
              final seconds = _dailyWorkingHours[dayName] ?? 0;
              return BarTooltipItem(
                _formatDuration(seconds),
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      days[value.toInt()],
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const Text('');
                return Text(
                  '${value.toInt()}h',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.border.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (index) {
          final dayName = dayNames[index];
          final seconds = _dailyWorkingHours[dayName] ?? 0;
          final hours = seconds / 3600.0;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: hours,
                color: const Color(0xFF3B82F6),
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxHours,
                  color: AppColors.border.withOpacity(0.1),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft, size: 18, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Summary',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Toggle Switch
                    _buildToggle(),
                    const SizedBox(height: 24),
                    // Content based on toggle
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _showBranchSummary
                          ? _buildBranchSummary()
                          : _buildMySummary(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildToggle() {
    return AnimatedToggle(
      backgroundColor: Colors.white,
      values: const ['My Summary', 'Branch Summary'],
      selectedIndex: _showBranchSummary ? 1 : 0,
      onChanged: (index) => setState(() => _showBranchSummary = index == 1),
    );
  }

  Widget _buildMySummary() {
    return Column(
      key: const ValueKey('my_summary'),
      children: [
        // Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF2D8F), Color(0xFFFF6FB5)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF2D8F).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.userCheck,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'My Performance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _getDateString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Stats Grid
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.circleCheck,
                '$_myCompletedServices',
                'Services Done',
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.dollarSign,
                '\$${_myRevenue.toStringAsFixed(0)}',
                'Revenue Generated',
                const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.calendarCheck,
                '$_myTotalBookings',
                'Total Bookings',
                const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.star,
                _myCompletedServices > 0 ? '4.8' : '—',
                'Rating',
                const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Weekly Working Hours Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.clock,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Weekly Working Hours',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_totalWeeklyHours),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This Week',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              // Bar Chart
              SizedBox(
                height: 200,
                child: _buildWeeklyHoursChart(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Tips Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.lightbulb,
                      color: Color(0xFFF59E0B),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Performance Tip',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _myCompletedServices > 0
                    ? 'Great work! You\'ve completed $_myCompletedServices services. Keep up the excellent performance! 🌟'
                    : 'Start completing services to see your performance stats here.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBranchSummary() {
    return Column(
      key: const ValueKey('branch_summary'),
      children: [
        // Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF34D399)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.building,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _branchName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Branch Overview',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Stats Grid
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.dollarSign,
                '\$${_branchRevenue.toStringAsFixed(0)}',
                'Total Revenue',
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.calendarDays,
                '$_branchBookings',
                'Total Bookings',
                const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.users,
                '$_branchStaffCount',
                'Staff Members',
                const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.circleCheck,
                '$_branchCompletedBookings',
                'Completed',
                const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.clock,
                '$_branchPendingBookings',
                'Pending',
                const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.chartLine,
                _branchBookings > 0
                    ? '${((_branchCompletedBookings / _branchBookings) * 100).toStringAsFixed(0)}%'
                    : '—',
                'Completion Rate',
                const Color(0xFFEC4899),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Branch Info Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.chartPie,
                      color: Color(0xFF3B82F6),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Branch Insights',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _branchBookings > 0
                    ? 'Your branch has processed $_branchBookings bookings with $_branchStaffCount active staff members. '
                      '${_branchCompletedBookings > 0 ? "Keep up the great work! 💪" : "Focus on completing pending bookings."}'
                    : 'No bookings yet for this branch. Start accepting bookings to see insights here.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  String _getDateString() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}
