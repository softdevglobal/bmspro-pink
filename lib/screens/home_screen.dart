import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import '../widgets/pink_bottom_nav.dart';
import 'calender_screen.dart';
import 'report_screen.dart';
import 'profile_screen.dart';
import 'notifications_page.dart';

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
      });
    }
  }

  void _handleBreakAction() {
    _startLoading(() {
      setState(() {
        if (_status == ClockStatus.clockedIn) {
          _status = ClockStatus.onBreak;
        } else {
          _status = ClockStatus.clockedIn;
        }
      });
    });
  }

  // Simulate network/processing delay
  void _startLoading(VoidCallback onComplete) {
    // Here you would add sound effects logic
    Future.delayed(const Duration(seconds: 1), onComplete);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _navIndex == 0
          ? SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStatusCard(),
                    const SizedBox(height: 24),
                    _buildAppointmentsSection(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                  ],
                ),
              ),
            )
          : _buildTabBody(),
      bottomNavigationBar: PinkBottomNav(
        currentIndex: _navIndex,
        onChanged: (index) => setState(() => _navIndex = index),
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_navIndex) {
      case 1:
        return const CalenderScreen();
      case 2:
        return const ReportScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- UI Components ---
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.08),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
                image: const DecorationImage(
                  image: NetworkImage(
                      'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-5.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi Emma',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  'Tuesday, 17 March',
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
              )
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
          text: 'Finish Break',
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
          const SizedBox(height: 16),
          mainButton,
          if (secondaryButton != null) secondaryButton,
        ],
      ),
    );
  }

  Widget _buildAppointmentsSection() {
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
                child: const Text('3',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          _buildAppointmentItem(
            'Massage 60min',
            '10:00 AM',
            FontAwesomeIcons.spa,
            [Colors.purple.shade400, Colors.purple.shade600],
            isNext: true,
          ),
          _buildAppointmentItem(
            'Facial 45min',
            '12:00 PM',
            FontAwesomeIcons.leaf,
            [Colors.pink.shade400, Colors.pink.shade600],
          ),
          _buildAppointmentItem(
            'Nails 45min',
            '3:00 PM',
            FontAwesomeIcons.handSparkles,
            [AppColors.accent, AppColors.primary],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
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

  Widget _buildAppointmentItem(
    String title,
    String time,
    IconData icon,
    List<Color> gradientColors, {
    bool isNext = false,
  }) {
    return Container(
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
                Text(time,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          if (isNext)
            const Text('Next',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildActionBtn('My Tasks', FontAwesomeIcons.listCheck,
                [Colors.blue.shade400, Colors.blue.shade600]),
            const SizedBox(width: 12),
            _buildActionBtn('Calendar', FontAwesomeIcons.calendar,
                [Colors.green.shade400, Colors.green.shade600]),
            const SizedBox(width: 12),
            _buildActionBtn('Profile', FontAwesomeIcons.user,
                [AppColors.primary, AppColors.accent]),
          ],
        )
      ],
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
class BranchSelectionDialog extends StatelessWidget {
  final Function(String) onBranchSelected;
  const BranchSelectionDialog({super.key, required this.onBranchSelected});

  @override
  Widget build(BuildContext context) {
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
            const Text(
              "Choose the location you're clocking in at",
              style: TextStyle(fontSize: 14, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildBranchOption(
                'Toorak', [Colors.purple.shade400, Colors.purple.shade600]),
            _buildBranchOption(
                'Burwood', [Colors.blue.shade400, Colors.blue.shade600]),
            _buildBranchOption(
                'Cranbourne', [Colors.green.shade400, Colors.green.shade600]),
            _buildBranchOption(
                'Dandenong', [Colors.orange.shade400, Colors.orange.shade600]),
            _buildBranchOption(
                'Richmond', [Colors.pink.shade400, Colors.pink.shade600]),
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

  Widget _buildBranchOption(String name, List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onBranchSelected(name),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                ],
              ),
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
