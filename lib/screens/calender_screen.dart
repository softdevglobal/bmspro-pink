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
  DateTime _focusedMonth = DateTime(2025, 3, 1);
  DateTime _selectedDate = DateTime(2025, 3, 17);

  late Map<int, DaySchedule> _scheduleData;
  
  // Role & filtering state
  String? _currentUserRole;
  String? _currentUserId;
  bool _isBranchView = false; // false = My Schedule, true = Branch Schedule
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
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
            _isLoadingRole = false;
          });
        }
      } else {
         if (mounted) setState(() => _isLoadingRole = false);
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  void _initializeData() {
    // Assign some items to a mock "current user" ID and others to different IDs
    // Since we don't know the real UID at compile time, we'll use placeholders
    // and logic in filtering will handle it. For demo purposes, assume
    // 'current_user_id' matches the logged in user if we want to test "My Schedule"
    // effectively with mock data, but we will implement filtering logic.
    
    // Using 'me' as a placeholder for current user's appointments in mock data
    const myId = 'me'; 
    const otherId = 'other';

    _scheduleData = {
      15: DaySchedule(branch: 'Main St', items: [
        Appointment(
            time: '10:00 AM',
            client: 'Sarah Johnson',
            service: 'Massage - 60m',
            room: 'R1',
            icon: FontAwesomeIcons.spa,
            staffId: myId),
      ]),
      16: DaySchedule(branch: 'Downtown', items: [
        Appointment(
            time: '09:00 AM',
            client: 'Mike Ross',
            service: 'Deep Tissue',
            room: 'D2',
            icon: FontAwesomeIcons.handSparkles,
            staffId: otherId),
        Appointment(
            time: '11:30 AM',
            client: 'Rachel Green',
            service: 'Manicure',
            room: 'D4',
            icon: FontAwesomeIcons.gem,
            staffId: myId),
      ]),
      17: DaySchedule(branch: 'Main St', items: [
        Appointment(
            time: '10:00 AM',
            client: 'Sarah Johnson',
            service: 'Massage - 60m',
            room: 'R1',
            icon: FontAwesomeIcons.spa,
            staffId: myId),
        Appointment(
            time: '12:00 PM',
            client: 'Emily Davis',
            service: 'Facial - 45m',
            room: 'R2',
            icon: FontAwesomeIcons.faceSmile,
            staffId: otherId),
        Appointment(
            time: '03:00 PM',
            client: 'Jessica Miller',
            service: 'Manicure',
            room: 'R3',
            icon: FontAwesomeIcons.handSparkles,
            staffId: myId),
      ]),
      18: DaySchedule(isOffDay: true),
      20: DaySchedule(branch: 'Westside', items: [
        Appointment(
            time: '01:00 PM',
            client: 'John Doe',
            service: 'Pedicure',
            room: 'W1',
            icon: FontAwesomeIcons.shoePrints,
            staffId: myId),
        Appointment(
            time: '02:30 PM',
            client: 'Jane Smith',
            service: 'Massage',
            room: 'W2',
            icon: FontAwesomeIcons.spa,
            staffId: otherId),
      ]),
      22: DaySchedule(branch: 'Downtown', items: [
        Appointment(
            time: '09:00 AM',
            client: 'Alice Cooper',
            service: 'Facial',
            room: 'D1',
            icon: FontAwesomeIcons.faceSmile,
            staffId: otherId),
      ]),
      24: DaySchedule(branch: 'Westside', items: [
        Appointment(
            time: '04:00 PM',
            client: 'Gary Oldman',
            service: 'Haircut',
            room: 'W4',
            icon: FontAwesomeIcons.scissors,
            staffId: myId),
      ]),
    };
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + offset, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: Column(
              children: [
                Text(
                  _isBranchView ? 'Branch Schedule' : 'My Schedule',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppConfig.text,
                  ),
                ),
                if (isBranchAdmin) ...[
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
        _scheduleData[dayInt]; // Simple logic: assumes mock data matches month
    List<Color> gradient = [Colors.grey.shade400, Colors.grey.shade300];
    String branchName = "No Schedule";
    if (data != null) {
      if (data.isOffDay) {
        branchName = "Day Off";
        gradient = [Colors.grey.shade400, Colors.grey.shade300];
      } else if (data.branch != null) {
        branchName = "${data.branch} Branch";
        gradient = AppConfig.branches[data.branch]!.gradient;
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

    // Filter items based on view mode
    final filteredItems = data.items.where((appt) {
      if (_currentUserRole == 'salon_branch_admin' && _isBranchView) {
        // Branch admin can see everything in branch view
        return true; 
      }
      // Otherwise (staff view or admin toggled to 'My Schedule'), only show 'me'
      // In real app, compare appt.staffId == _currentUserId
      return appt.staffId == 'me';
    }).toList();

    if (filteredItems.isEmpty) {
       return _emptyState(
          FontAwesomeIcons.calendarXmark, "No appointments for you today.");
    }

    return Column(
      children: filteredItems.map((appt) {
        final theme = AppConfig.branches[data.branch]!;
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
}
