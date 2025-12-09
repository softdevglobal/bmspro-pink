import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/animated_toggle.dart';

class Appointment {
  final String time;
  final String client;
  final String service;
  final String room;
  final IconData icon;
  final String staffId; // Added to support filtering
  
  Appointment({
    required this.time,
    required this.client,
    required this.service,
    required this.room,
    required this.icon,
    required this.staffId,
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

    for (final data in _allBookings) {
      // Status filter: confirmed only
      final statusRaw = (data['status'] ?? '').toString().toLowerCase();
      if (statusRaw != 'confirmed') continue;

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
      final clientName = (data['client'] ?? 'Walk-in').toString();

      // Derive service name similar to owner bookings page
      String serviceName = (data['serviceName'] ?? '').toString();
      if (serviceName.isEmpty && data['services'] is List) {
        final list = data['services'] as List;
        if (list.isNotEmpty && list.first is Map) {
          final first = list.first as Map;
          serviceName = (first['name'] ?? 'Service').toString();
        }
      }
      if (serviceName.isEmpty) serviceName = 'Service';

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
      }

      final appt = Appointment(
        time: timeLabel,
        client: clientName,
        service: serviceName,
        room: roomLabel,
        icon: icon,
        staffId: _extractStaffId(data),
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
                branchColor = AppConfig.branches[dayData.branch]!.color;
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
    List<Color> gradient = [Colors.grey.shade400, Colors.grey.shade300];
    String branchName = "No Schedule";
    if (data != null) {
      if (data.isOffDay) {
        branchName = "Day Off";
        gradient = [Colors.grey.shade400, Colors.grey.shade300];
      } else if (data.branch != null) {
        branchName = "${data.branch} Branch";
        final theme = _resolveBranchTheme(data.branch);
        gradient = theme.gradient;
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(_selectedDate),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(FontAwesomeIcons.locationDot,
                      size: 14, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    branchName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(FontAwesomeIcons.calendarDay,
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

    return Column(
      children: filteredItems.map((appt) {
        final theme = _resolveBranchTheme(data.branch);
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
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
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
                            const SizedBox(height: 4),
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
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Text(
                          'Confirmed',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700),
                        ),
                      )
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppConfig.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoItem(FontAwesomeIcons.clock, appt.time, theme.color),
                      _infoItem(
                          FontAwesomeIcons.user, appt.client, theme.color),
                      _infoItem(
                          FontAwesomeIcons.doorOpen, appt.room, theme.color),
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
