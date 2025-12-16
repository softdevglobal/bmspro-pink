import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// --- 1. Theme & Colors ---
class AppColors {
  static const primary = Color(0xFFFF2D8F);
  static const primaryDark = Color(0xFFD81F75);
  static const accent = Color(0xFFFF6FB5);
  static const background = Color(0xFFFFF5FA);
  static const card = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF9E9E9E);
  static const border = Color(0xFFF2D2E9);
  static const green = Color(0xFF22C55E);
}

class TaskDetailsPage extends StatefulWidget {
  final Map<String, dynamic>? appointmentData;
  
  const TaskDetailsPage({super.key, this.appointmentData});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> with TickerProviderStateMixin {
  // --- Stopwatch State ---
  Timer? _stopwatchTimer;
  int _elapsedSeconds = 0;
  bool _isStopwatchRunning = false;
  DateTime? _appointmentStartTime;

  // --- Task State ---
  bool _isNotesExpanded = false;
  bool _isFinishing = false;
  bool _isLoading = true;

  // Appointment Data
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _customerData;
  String _serviceName = 'Service';
  String _duration = '60';
  String _appointmentTime = '';
  String _location = 'Salon';
  String _customerName = 'Customer';
  String _serviceType = '';
  String _customerNotes = 'No special notes available.';

  // Mock Data from HTML
  final List<Map<String, dynamic>> _tasks = [
    {'id': 1, 'title': 'Room sanitization', 'icon': FontAwesomeIcons.sprayCanSparkles, 'completed': false},
    {'id': 2, 'title': 'Temperature adjustment', 'icon': FontAwesomeIcons.temperatureHalf, 'completed': false},
    {'id': 3, 'title': 'Lighting setup', 'icon': FontAwesomeIcons.lightbulb, 'completed': false},
    {'id': 4, 'title': 'Ambient music', 'icon': FontAwesomeIcons.music, 'completed': false},
    {'id': 5, 'title': 'Essential oils ready', 'icon': FontAwesomeIcons.droplet, 'completed': false},
    {'id': 6, 'title': 'Towels warmed', 'icon': FontAwesomeIcons.handSparkles, 'completed': false},
    {'id': 7, 'title': 'Client form reviewed', 'icon': FontAwesomeIcons.clipboardCheck, 'completed': false},
  ];

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // 2. Setup Pulse Animation for Finish Button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadAppointmentData();
  }

  Future<void> _loadAppointmentData() async {
    if (widget.appointmentData == null) {
      setState(() => _isLoading = false);
      _startStopwatch();
      return;
    }

    try {
      _bookingData = widget.appointmentData!['data'] as Map<String, dynamic>?;
      final bookingId = widget.appointmentData!['id'] as String?;
      
      // Load full booking data if we have an ID
      if (bookingId != null && _bookingData == null) {
        final bookingDoc = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .get();
        if (bookingDoc.exists) {
          _bookingData = bookingDoc.data();
        }
      }

      // Extract service information
      _serviceName = widget.appointmentData?['serviceName']?.toString() ?? 
                    _bookingData?['serviceName']?.toString() ?? 
                    'Service';
      _duration = widget.appointmentData?['duration']?.toString() ?? 
                 _bookingData?['duration']?.toString() ?? 
                 '60';
      
      // Extract time and location
      final time = widget.appointmentData?['time']?.toString() ?? 
                  _bookingData?['time']?.toString() ?? 
                  _bookingData?['startTime']?.toString() ?? '';
      _appointmentTime = _formatTime(time);
      
      _location = _bookingData?['branchName']?.toString() ?? 
                 _bookingData?['room']?.toString() ?? 
                 _bookingData?['location']?.toString() ?? 
                 'Salon';

      // Extract customer information
      _customerName = _bookingData?['client']?.toString() ?? 
                     _bookingData?['clientName']?.toString() ?? 
                     widget.appointmentData?['client']?.toString() ?? 
                     'Customer';
      
      // Try to get service type from services array or use service name
      if (_bookingData?['services'] is List && (_bookingData!['services'] as List).isNotEmpty) {
        final firstService = (_bookingData!['services'] as List).first;
        if (firstService is Map) {
          _serviceType = firstService['name']?.toString() ?? _serviceName;
        }
      } else {
        _serviceType = _serviceName;
      }

      // Get customer notes
      _customerNotes = _bookingData?['customerNotes']?.toString() ?? 
                      _bookingData?['notes']?.toString() ?? 
                      'No special notes available.';

      // Try to find customer in customers collection for additional info
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final ownerUid = user.uid;
        final customerEmail = _bookingData?['email']?.toString() ?? 
                             _bookingData?['clientEmail']?.toString() ?? '';
        final customerPhone = _bookingData?['phone']?.toString() ?? 
                             _bookingData?['clientPhone']?.toString() ?? '';
        
        QuerySnapshot? customerSnap;
        if (customerEmail.isNotEmpty) {
          customerSnap = await FirebaseFirestore.instance
              .collection('customers')
              .where('ownerUid', isEqualTo: ownerUid)
              .where('email', isEqualTo: customerEmail)
              .limit(1)
              .get();
        }
        if ((customerSnap == null || customerSnap.docs.isEmpty) && customerPhone.isNotEmpty) {
          customerSnap = await FirebaseFirestore.instance
              .collection('customers')
              .where('ownerUid', isEqualTo: ownerUid)
              .where('phone', isEqualTo: customerPhone)
              .limit(1)
              .get();
        }
        
        if (customerSnap != null && customerSnap.docs.isNotEmpty) {
          _customerData = customerSnap.docs.first.data() as Map<String, dynamic>;
          // Use customer notes from customer profile if available
          final customerNotesFromProfile = _customerData?['notes']?.toString() ?? 
                                           _customerData?['customerNotes']?.toString() ?? '';
          if (customerNotesFromProfile.isNotEmpty) {
            _customerNotes = customerNotesFromProfile;
          }
        }
      }

      // Calculate elapsed time if appointment has started
      final date = widget.appointmentData?['date']?.toString() ?? 
                  _bookingData?['date']?.toString() ?? '';
      if (date.isNotEmpty && time.isNotEmpty) {
        try {
          final dateTime = DateTime.parse(date);
          final timeParts = time.split(':');
          if (timeParts.length >= 2) {
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            _appointmentStartTime = DateTime(
              dateTime.year,
              dateTime.month,
              dateTime.day,
              hour,
              minute,
            );
            
            // If appointment has started, calculate elapsed time
            final now = DateTime.now();
            if (now.isAfter(_appointmentStartTime!)) {
              _elapsedSeconds = now.difference(_appointmentStartTime!).inSeconds;
            }
          }
        } catch (_) {
          // If parsing fails, start from 0
        }
      }

    } catch (e) {
      debugPrint('Error loading task data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
      // Auto-start stopwatch on load
      _startStopwatch();
    }
  }

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    if (time.toUpperCase().contains('AM') || time.toUpperCase().contains('PM')) {
      return time;
    }
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

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // --- Stopwatch Logic ---
  void _startStopwatch() {
    if (_isStopwatchRunning) return;
    setState(() => _isStopwatchRunning = true);
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _stopStopwatch() {
    _stopwatchTimer?.cancel();
    setState(() => _isStopwatchRunning = false);
  }

  void _toggleStopwatch() {
    if (_isStopwatchRunning) {
      _stopStopwatch();
    } else {
      _startStopwatch();
    }
  }

  String _formatElapsedTime(int totalSeconds) {
    final hrs = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final mins = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$hrs:$mins:$secs";
  }

  // --- Task Progress Logic ---
  int get _completedCount => _tasks.where((t) => t['completed']).length;
  int get _totalCount => _tasks.length;
  double get _progress => _totalCount == 0 ? 0 : _completedCount / _totalCount;
  bool get _isComplete => _completedCount == _totalCount;
  
  // Check if service type requires task list (services like haircut, cut, trim don't need it)
  bool get _requiresTaskList {
    final serviceLower = _serviceName.toLowerCase();
    // Services that don't need task list: haircut, cut, trim, color, etc.
    if (serviceLower.contains('hair') && 
        (serviceLower.contains('cut') || serviceLower.contains('trim'))) {
      return false;
    }
    if (serviceLower.contains('cut') && !serviceLower.contains('nail')) {
      return false;
    }
    if (serviceLower.contains('trim')) {
      return false;
    }
    if (serviceLower.contains('color') || serviceLower.contains('colour')) {
      return false;
    }
    // Services that typically need task list: massage, facial, spa, etc.
    return true;
  }

  void _toggleTask(int index) {
    setState(() {
      _tasks[index]['completed'] = !_tasks[index]['completed'];
      // Trigger pulse animation if all done
      if (_isComplete) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  void _handleFinish() async {
    // For services that require task list, check if all tasks are complete
    // For services that don't require task list (like haircut), allow finishing immediately
    if (_requiresTaskList && !_isComplete) return;
    
    // Stop timer on finish
    _stopStopwatch();
    setState(() => _isFinishing = true);
    
    try {
      // Update booking status to completed if we have booking data
      final bookingId = widget.appointmentData?['id'] as String?;
      if (bookingId != null) {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'durationElapsed': _elapsedSeconds,
        });
      }
    } catch (e) {
      debugPrint('Error updating booking status: $e');
    }
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isFinishing = false);
      Navigator.pop(context); // Go back to previous screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Task Completed Successfully!"),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  // --- UI Construction ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildServiceHeader(),
                    const SizedBox(height: 24),
                    _buildCustomerInfo(),
                    if (_requiresTaskList) ...[
                      const SizedBox(height: 24),
                      _buildTasksSection(),
                    ],
                    const SizedBox(height: 24),
                    _buildFinishSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(color: AppColors.background),
      child: Row(
        children: const [
          _BackChevron(),
          Expanded(
            child: Center(
              child: Text(
                'Task Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
            ),
          ),
          SizedBox(width: 24),
        ],
      ),
    );
  }

  IconData _getServiceIcon(String serviceName) {
    final serviceLower = serviceName.toLowerCase();
    if (serviceLower.contains('nail') || serviceLower.contains('manicure') || serviceLower.contains('pedicure')) {
      return FontAwesomeIcons.handSparkles;
    } else if (serviceLower.contains('facial') || serviceLower.contains('face')) {
      return FontAwesomeIcons.leaf;
    } else if (serviceLower.contains('hair') || serviceLower.contains('cut') || serviceLower.contains('style')) {
      return FontAwesomeIcons.scissors;
    } else if (serviceLower.contains('wax') || serviceLower.contains('threading')) {
      return FontAwesomeIcons.feather;
    } else if (serviceLower.contains('makeup') || serviceLower.contains('beauty')) {
      return FontAwesomeIcons.wandMagicSparkles;
    } else if (serviceLower.contains('color') || serviceLower.contains('colour')) {
      return FontAwesomeIcons.paintbrush;
    }
    return FontAwesomeIcons.spa;
  }

  Widget _buildServiceHeader() {
    final durationDisplay = '${_duration} Minutes Session';
    final serviceIcon = _getServiceIcon(_serviceName);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 25, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _serviceName,
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      durationDisplay,
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                child: Center(child: Icon(serviceIcon, color: Colors.white, size: 24)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(FontAwesomeIcons.clock, color: Colors.white, size: 14),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _appointmentTime.isNotEmpty ? _appointmentTime : 'Time TBD',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(FontAwesomeIcons.doorOpen, color: Colors.white, size: 14),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _location,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // --- Stopwatch Component ---
              GestureDetector(
                onTap: _toggleStopwatch,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: _isStopwatchRunning ? Border.all(color: Colors.white.withOpacity(0.5)) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isStopwatchRunning ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatElapsedTime(_elapsedSeconds),
                        style: GoogleFonts.robotoMono(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FontAwesomeIcons.circleUser, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text('Customer Information', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('Name', _customerName),
          const SizedBox(height: 12),
          _infoRow('Service Type', _serviceType.isNotEmpty ? _serviceType : _serviceName),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          InkWell(
            onTap: () => setState(() => _isNotesExpanded = !_isNotesExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Special Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary)),
                  Icon(_isNotesExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.chevronDown, size: 14, color: AppColors.primary),
                ],
              ),
            ),
          ),
          if (_isNotesExpanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: Text(
                _customerNotes,
                style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: AppColors.text),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTasksSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(FontAwesomeIcons.listCheck, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text('Tasks to Complete', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('$_completedCount/$_totalCount', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 12,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${(_progress * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          const SizedBox(height: 16),
          // Task List
          ...List.generate(_tasks.length, (index) {
            final task = _tasks[index];
            final isDone = task['completed'];
            return GestureDetector(
              onTap: () => _toggleTask(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDone ? AppColors.primary.withOpacity(0.05) : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDone ? AppColors.primary.withOpacity(0.3) : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Icon(task['icon'], size: 14, color: AppColors.muted)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(task['title'], style: GoogleFonts.inter(fontSize: 14, color: AppColors.text)),
                    ),
                    Icon(
                      isDone ? FontAwesomeIcons.solidCircleCheck : FontAwesomeIcons.circle,
                      size: 18,
                      color: isDone ? AppColors.primary : AppColors.border,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFinishSection() {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: (_requiresTaskList ? _isComplete : true) 
                  ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) 
                  : null,
              color: (_requiresTaskList ? _isComplete : true) ? null : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(16),
              boxShadow: (_requiresTaskList ? _isComplete : true) 
                  ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)] 
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (!_isFinishing && (_requiresTaskList ? _isComplete : true)) ? _handleFinish : null,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: _isFinishing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FontAwesomeIcons.circleCheck, 
                              color: (_requiresTaskList ? _isComplete : true) ? Colors.white : Colors.grey.shade500, 
                              size: 20
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Finish Task',
                              style: GoogleFonts.inter(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold, 
                                color: (_requiresTaskList ? _isComplete : true) ? Colors.white : Colors.grey.shade500
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_requiresTaskList)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_isComplete ? FontAwesomeIcons.check : FontAwesomeIcons.triangleExclamation, size: 14, color: _isComplete ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Text(
                _isComplete ? 'All tasks completed! Ready to finish' : 'Complete all tasks to finish',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: _isComplete ? Colors.green : Colors.orange),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(FontAwesomeIcons.check, size: 14, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Ready to finish',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.green),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: BottomNavigationBar(
        backgroundColor: AppColors.card,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.muted,
        items: const [
          BottomNavigationBarItem(icon: Icon(FontAwesomeIcons.house), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(FontAwesomeIcons.calendar), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(FontAwesomeIcons.users), label: 'Clients'),
          BottomNavigationBarItem(icon: Icon(FontAwesomeIcons.chartSimple), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(FontAwesomeIcons.gear), label: 'Settings'),
        ],
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: AppColors.muted, fontSize: 14)),
        Text(value, style: GoogleFonts.inter(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 8))],
    );
  }
}

// Back chevron to match other pages
class _BackChevron extends StatelessWidget {
  const _BackChevron();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: const Icon(FontAwesomeIcons.chevronLeft, size: 18, color: AppColors.text),
    );
  }
}


