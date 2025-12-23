import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/animated_toggle.dart';
import '../services/staff_check_in_service.dart';

class AppColors {
  static const primary = Color(0xFFFF2D8F);
  static const accent = Color(0xFFFF6FB5);
  static const background = Color(0xFFFFF5FA);
  static const card = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF9E9E9E);
  static const border = Color(0xFFF2D2E9);
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _selectedTab = 'day'; // 'day', 'week', 'month'
  
  // Role & Toggle state
  String? _currentUserRole;
  bool _isBranchView = false; // false = My Summary, true = Branch Summary
  bool _isLoadingRole = true;
  Map<String, int> _dailyWorkingHours = {}; // Day-wise working hours in seconds
  int _totalWeeklyHours = 0; // Total weekly hours in seconds

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _loadWeeklyWorkingHours();
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

  Future<void> _loadWeeklyWorkingHours() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _calculateWeeklyWorkingHours(user.uid);
      }
    } catch (e) {
      debugPrint('Error loading weekly working hours: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    final bool isBranchAdmin = _currentUserRole == 'salon_branch_admin';

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            _isBranchView ? 'Branch Summary' : 'My Summary',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
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
                  _buildTabs(),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _buildCurrentView(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return SizedBox(
      width: 300,
      child: AnimatedToggle(
        backgroundColor: Colors.white,
        values: const ['My Summary', 'Branch Summary'],
        selectedIndex: _isBranchView ? 1 : 0,
        onChanged: (index) => setState(() => _isBranchView = index == 1),
      ),
    );
  }

  // Removed manual toggle buttons


  Widget _iconButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(icon, size: 16, color: AppColors.text)),
    );
  }

  Widget _buildTabs() {
    final tabs = ['day', 'week', 'month'];
    return AnimatedToggle(
      backgroundColor: Colors.white,
      values: const ['Day', 'Week', 'Month'],
      selectedIndex: tabs.indexOf(_selectedTab),
      onChanged: (index) => setState(() => _selectedTab = tabs[index]),
    );
  }

  // Removed manual tab buttons


  Widget _buildCurrentView() {
    switch (_selectedTab) {
      case 'day':
        return _buildDayView();
      case 'week':
        return _buildWeekView();
      case 'month':
        return _buildMonthView();
      default:
        return _buildDayView();
    }
  }

  Widget _buildDayView() {
    // Mock Data Switch
    final hours = _isBranchView ? '45h 30m' : '7h 45m';
    final tasks = _isBranchView ? '42' : '6';
    final tips = _isBranchView ? '\$580' : '\$85';
    final rating = _isBranchView ? '4.9' : '4.8';

    return Column(
      key: const ValueKey('day'),
      children: [
        _buildSummaryHeader('Daily Summary', 'Tuesday, 17 March 2025'),
        const SizedBox(height: 24),
        _buildKpiGrid([
          _KpiData(FontAwesomeIcons.clock, hours, 'Hours Worked'),
          _KpiData(FontAwesomeIcons.circleCheck, tasks, 'Tasks Completed'),
          _KpiData(FontAwesomeIcons.dollarSign, tips, 'Total Tips'),
          _KpiData(FontAwesomeIcons.star, rating, 'Rating'),
        ]),
        const SizedBox(height: 24),
        if (!_isBranchView && (_currentUserRole == 'salon_staff' || _currentUserRole == 'salon_branch_admin')) ...[
          _buildWeeklyWorkingHoursCard(),
          const SizedBox(height: 24),
        ],
        if (!_isBranchView) ...[
          _buildNotesCard(),
          const SizedBox(height: 24),
        ],
        _buildDownloadBtn('Download Day PDF'),
      ],
    );
  }

  Widget _buildWeekView() {
    // Mock Data Switch
    final totalHours = _isBranchView ? '280h' : '38h 12m';
    final tasks = _isBranchView ? '195' : '28';
    final tips = _isBranchView ? '\$2,450' : '\$360';
    final rating = _isBranchView ? '4.8' : '4.7';

    return Column(
      key: const ValueKey('week'),
      children: [
        _buildSummaryHeader('Week Summary', '10 → 17 March 2025'),
        const SizedBox(height: 24),
        _buildKpiGrid([
          _KpiData(FontAwesomeIcons.clock, totalHours, 'Total Hours'),
          _KpiData(FontAwesomeIcons.listCheck, tasks, 'Tasks Completed'),
          _KpiData(FontAwesomeIcons.dollarSign, tips, 'Total Tips'),
          _KpiData(FontAwesomeIcons.star, rating, 'Avg Rating'),
        ]),
        const SizedBox(height: 24),
        if (!_isBranchView && (_currentUserRole == 'salon_staff' || _currentUserRole == 'salon_branch_admin')) ...[
          _buildWeeklyWorkingHoursCard(),
          const SizedBox(height: 24),
        ],
        _buildChartContainer('Hours per Day', _buildWeekChart()),
        const SizedBox(height: 24),
        _buildDownloadBtn('Download Week PDF'),
      ],
    );
  }

  Widget _buildMonthView() {
    // Mock Data Switch
    final totalHours = _isBranchView ? '1,200h' : '152h';
    final tasks = _isBranchView ? '850' : '118';
    final tips = _isBranchView ? '\$9,500' : '\$1,240';
    final rating = _isBranchView ? '4.85' : '4.75';

    return Column(
      key: const ValueKey('month'),
      children: [
        _buildSummaryHeader('Month Summary', 'March 2025'),
        const SizedBox(height: 24),
        _buildKpiGrid([
          _KpiData(FontAwesomeIcons.clock, totalHours, 'Total Hours'),
          _KpiData(FontAwesomeIcons.listCheck, tasks, 'Tasks Completed'),
          _KpiData(FontAwesomeIcons.dollarSign, tips, 'Total Tips'),
          _KpiData(FontAwesomeIcons.star, rating, 'Avg Rating'),
        ]),
        const SizedBox(height: 24),
        if (!_isBranchView && (_currentUserRole == 'salon_staff' || _currentUserRole == 'salon_branch_admin')) ...[
          _buildWeeklyWorkingHoursCard(),
          const SizedBox(height: 24),
        ],
        _buildChartContainer('Weekly Breakdown', _buildMonthChart()),
        const SizedBox(height: 24),
        _buildDownloadBtn('Download Month PDF'),
      ],
    );
  }

  Widget _buildSummaryHeader(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(List<_KpiData> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildKpiCard(items[index]);
      },
    );
  }

  Widget _buildKpiCard(_KpiData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent]),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Center(child: Icon(data.icon, color: Colors.white, size: 18)),
          ),
          Text(
            data.value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyWorkingHoursCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
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
    );
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

  Widget _buildNotesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          SizedBox(height: 8),
          Text('Great work today! 🌸',
              style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _buildDownloadBtn(String text) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(FontAwesomeIcons.download,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartContainer(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
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
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 24),
          SizedBox(height: 250, child: chart),
        ],
      ),
    );
  }

  Widget _buildWeekChart() {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(days[value.toInt()],
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.muted)),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeGroupData(0, 7, AppColors.primary),
          _makeGroupData(1, 6, AppColors.accent),
          _makeGroupData(2, 5.5, AppColors.primary),
          _makeGroupData(3, 8, AppColors.accent),
          _makeGroupData(4, 5, AppColors.primary),
          _makeGroupData(5, 6.5, AppColors.accent),
          _makeGroupData(6, 0, Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _buildMonthChart() {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < 4) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Week ${value.toInt() + 1}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.muted)),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeGroupData(0, 32, AppColors.primary),
          _makeGroupData(1, 35, AppColors.accent),
          _makeGroupData(2, 38, AppColors.primary),
          _makeGroupData(3, 47, AppColors.accent),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 16,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 50,
            color: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }
}

class _KpiData {
  final IconData icon;
  final String value;
  final String label;
  _KpiData(this.icon, this.value, this.label);
}
