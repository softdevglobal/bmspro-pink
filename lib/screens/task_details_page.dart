import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
}

class TaskDetailsPage extends StatefulWidget {
  const TaskDetailsPage({super.key});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> with TickerProviderStateMixin {
  // --- Stopwatch State ---
  Timer? _stopwatchTimer;
  int _elapsedSeconds = 0;
  bool _isStopwatchRunning = false;

  // --- Task State ---
  bool _isNotesExpanded = false;
  bool _isFinishing = false;

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
    // 1. Auto-start stopwatch on load
    _startStopwatch();
    // 2. Setup Pulse Animation for Finish Button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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

  String _formatTime(int totalSeconds) {
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
    if (!_isComplete) return;
    // Stop timer on finish
    _stopStopwatch();
    setState(() => _isFinishing = true);
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isFinishing = false);
      Navigator.pop(context); // Go back to previous screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task Completed Successfully!")),
      );
    }
  }

  // --- UI Construction ---
  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(height: 24),
                    _buildTasksSection(),
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

  Widget _buildServiceHeader() {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Massage', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('60 Minutes Session', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
                ],
              ),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                child: const Center(child: Icon(FontAwesomeIcons.spa, color: Colors.white, size: 24)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(FontAwesomeIcons.clock, color: Colors.white, size: 14),
                  const SizedBox(width: 8),
                  Text('10:00 AM', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                  const SizedBox(width: 16),
                  const Icon(FontAwesomeIcons.doorOpen, color: Colors.white, size: 14),
                  const SizedBox(width: 8),
                  Text('Room R1', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                ],
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
                        _formatTime(_elapsedSeconds),
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
          _infoRow('Name', 'Sarah Johnson'),
          const SizedBox(height: 12),
          _infoRow('Service Type', 'Deep Tissue'),
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
                'Relaxation style massage. Client prefers medium pressure. Has mild lower back tension. Lavender oil preferred.',
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
              gradient: _isComplete ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
              color: _isComplete ? null : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isComplete ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)] : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isComplete && !_isFinishing ? _handleFinish : null,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: _isFinishing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FontAwesomeIcons.circleCheck, color: _isComplete ? Colors.white : Colors.grey.shade500, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Finish Task',
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _isComplete ? Colors.white : Colors.grey.shade500),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
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


