import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

// ============================================================================
// DUMMY DATA MODELS
// ============================================================================

class AttendanceRecord {
  final String id;
  final String staffId;
  final String staffName;
  final String staffRole;
  final String? avatar;
  final DateTime date;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String status; // 'present', 'absent', 'late', 'half-day'
  final String? note;

  AttendanceRecord({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.staffRole,
    this.avatar,
    required this.date,
    this.clockIn,
    this.clockOut,
    required this.status,
    this.note,
  });

  String get formattedClockIn {
    if (clockIn == null) return '--:--';
    return '${clockIn!.hour.toString().padLeft(2, '0')}:${clockIn!.minute.toString().padLeft(2, '0')}';
  }

  String get formattedClockOut {
    if (clockOut == null) return '--:--';
    return '${clockOut!.hour.toString().padLeft(2, '0')}:${clockOut!.minute.toString().padLeft(2, '0')}';
  }

  String get hoursWorked {
    if (clockIn == null || clockOut == null) return '0h 0m';
    final diff = clockOut!.difference(clockIn!);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}

// ============================================================================
// ATTENDANCE PAGE
// ============================================================================

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime _selectedDate = DateTime.now();
  String _filterStatus = 'All';
  
  // Dummy data
  final List<AttendanceRecord> _dummyRecords = [
    AttendanceRecord(
      id: '1',
      staffId: 's1',
      staffName: 'Sarah Johnson',
      staffRole: 'Hair Stylist',
      date: DateTime.now(),
      clockIn: DateTime.now().copyWith(hour: 9, minute: 0),
      clockOut: DateTime.now().copyWith(hour: 17, minute: 30),
      status: 'present',
    ),
    AttendanceRecord(
      id: '2',
      staffId: 's2',
      staffName: 'Michael Chen',
      staffRole: 'Colorist',
      date: DateTime.now(),
      clockIn: DateTime.now().copyWith(hour: 9, minute: 15),
      clockOut: DateTime.now().copyWith(hour: 18, minute: 0),
      status: 'late',
      note: 'Traffic delay',
    ),
    AttendanceRecord(
      id: '3',
      staffId: 's3',
      staffName: 'Emma Wilson',
      staffRole: 'Nail Technician',
      date: DateTime.now(),
      clockIn: DateTime.now().copyWith(hour: 8, minute: 55),
      clockOut: DateTime.now().copyWith(hour: 13, minute: 0),
      status: 'half-day',
      note: 'Doctor appointment',
    ),
    AttendanceRecord(
      id: '4',
      staffId: 's4',
      staffName: 'James Brown',
      staffRole: 'Barber',
      date: DateTime.now(),
      status: 'absent',
      note: 'Sick leave',
    ),
    AttendanceRecord(
      id: '5',
      staffId: 's5',
      staffName: 'Lisa Martinez',
      staffRole: 'Makeup Artist',
      date: DateTime.now(),
      clockIn: DateTime.now().copyWith(hour: 10, minute: 0),
      status: 'present',
      note: 'Still working',
    ),
  ];

  List<AttendanceRecord> get _filteredRecords {
    if (_filterStatus == 'All') return _dummyRecords;
    return _dummyRecords.where((r) => r.status == _filterStatus.toLowerCase()).toList();
  }

  Map<String, int> get _statusCounts {
    return {
      'present': _dummyRecords.where((r) => r.status == 'present').length,
      'late': _dummyRecords.where((r) => r.status == 'late').length,
      'half-day': _dummyRecords.where((r) => r.status == 'half-day').length,
      'absent': _dummyRecords.where((r) => r.status == 'absent').length,
    };
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
          'Attendance',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Date Selector
          _buildDateSelector(),
          // Stats Overview
          _buildStatsOverview(),
          // Filter Tabs
          _buildFilterTabs(),
          // Attendance List
          Expanded(
            child: _filteredRecords.isEmpty
                ? _buildEmptyState()
                : _buildAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                  });
                },
                icon: const Icon(FontAwesomeIcons.chevronLeft, color: Colors.white, size: 16),
              ),
              Text(
                _getMonthYearString(_selectedDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 7));
                  });
                },
                icon: const Icon(FontAwesomeIcons.chevronRight, color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final date = startOfWeek.add(Duration(days: index));
              final isSelected = date.day == _selectedDate.day && 
                  date.month == _selectedDate.month && 
                  date.year == _selectedDate.year;
              final isToday = date.day == now.day && 
                  date.month == now.month && 
                  date.year == now.year;

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  width: 40,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        weekDays[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primary : Colors.white,
                        ),
                      ),
                      if (isToday && !isSelected)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    final counts = _statusCounts;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Present', counts['present'] ?? 0, Colors.green, FontAwesomeIcons.circleCheck)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard('Late', counts['late'] ?? 0, Colors.orange, FontAwesomeIcons.clock)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard('Half-day', counts['half-day'] ?? 0, Colors.blue, FontAwesomeIcons.circleHalfStroke)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard('Absent', counts['absent'] ?? 0, Colors.red, FontAwesomeIcons.circleXmark)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', 'Present', 'Late', 'Half-day', 'Absent'].map((status) {
            final isSelected = _filterStatus == status;
            return GestureDetector(
              onTap: () => setState(() => _filterStatus = status),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(FontAwesomeIcons.clipboardUser, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Records Found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No $_filterStatus attendance records for this day',
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final record = _filteredRecords[index];
        return _buildAttendanceCard(record);
      },
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final statusColor = _getStatusColor(record.status);
    final statusIcon = _getStatusIcon(record.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor.withOpacity(0.8), statusColor.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(record.staffName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.staffName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        record.staffRole,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        _capitalizeFirst(record.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Time Info
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: _buildTimeBox('Clock In', record.formattedClockIn, const Color(0xFF10B981)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTimeBox('Clock Out', record.formattedClockOut, const Color(0xFFEF4444)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTimeBox('Hours', record.hoursWorked, const Color(0xFF8B5CF6)),
                ),
              ],
            ),
          ),
          // Note (if any)
          if (record.note != null && record.note!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(FontAwesomeIcons.noteSticky, size: 12, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.note!,
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
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

  Widget _buildTimeBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'half-day':
        return Colors.blue;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present':
        return FontAwesomeIcons.circleCheck;
      case 'late':
        return FontAwesomeIcons.clock;
      case 'half-day':
        return FontAwesomeIcons.circleHalfStroke;
      case 'absent':
        return FontAwesomeIcons.circleXmark;
      default:
        return FontAwesomeIcons.circle;
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _getMonthYearString(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

