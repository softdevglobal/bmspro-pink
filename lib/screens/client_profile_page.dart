import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// --- 1. Theme & Colors (Matching HTML/Tailwind) ---
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
  static const yellow = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const redLight = Color(0xFFFEE2E2);
  static const blueLight = Color(0xFFF0F9FF);
  static const greenLight = Color(0xFFF0FDF4);
}

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({super.key});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  final List<Animation<double>> _fadeAnimations = [];

  @override
  void initState() {
    super.initState();
    // 1. Fade-in Staggered Animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    for (int i = 0; i < 5; i++) {
      final start = i * 0.1;
      final end = start + 0.4;
      _fadeAnimations.add(
        CurvedAnimation(
          parent: _fadeController,
          curve: Interval(start, end > 1.0 ? 1.0 : end, curve: Curves.easeOut),
        ),
      );
    }
    _fadeController.forward();
    // 2. Allergy Alert Pulse Animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

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
                    _buildFadeWrapper(0, _buildClientHeaderCard()),
                    const SizedBox(height: 24),
                    _buildFadeWrapper(1, _buildAllergyAlert()),
                    const SizedBox(height: 24),
                    _buildFadeWrapper(2, _buildFormulasSection()),
                    const SizedBox(height: 24),
                    _buildFadeWrapper(3, _buildHistorySection()),
                    const SizedBox(height: 40), // Bottom padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Animation Helper ---
  Widget _buildFadeWrapper(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_fadeAnimations[index]),
        child: child,
      ),
    );
  }

  // --- Header ---
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
                'Client Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
            ),
          ),
          SizedBox(width: 24),
        ],
      ),
    );
  }

  // --- Client Header Card ---
  Widget _buildClientHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: const DecorationImage(
                        image: NetworkImage('https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-5.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -5, right: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: const Text('VIP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.text)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sarah Johnson', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 4),
                    _iconTextRow(FontAwesomeIcons.phone, '+61 412 345 678'),
                    const SizedBox(height: 2),
                    _iconTextRow(FontAwesomeIcons.envelope, 'sarah.j@email.com'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Active Client', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _GradientButton(
                  text: 'Book Appointment',
                  icon: FontAwesomeIcons.calendarPlus,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
              _SecondaryButton(icon: FontAwesomeIcons.penToSquare, onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconTextRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }

  // --- Allergy Alert ---
  Widget _buildAllergyAlert() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.redLight, Color(0xFFFECACA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color.lerp(AppColors.red, const Color(0xFFDC2626), _pulseController.value)!,
              width: 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(FontAwesomeIcons.triangleExclamation, color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('🚨 ALLERGIES & WARNINGS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 14)),
                    SizedBox(height: 4),
                    Text('• Latex sensitivity\n• Ammonia-based colours\n• Lavender oil', style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.4)),
                    SizedBox(height: 12),
                    Text('⭐ PREFERENCES:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 12)),
                    SizedBox(height: 4),
                    Text('• Prefers warm water\n• Sensitive scalp\n• Avoid heavy fragrance', style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Formulas Section ---
  Widget _buildFormulasSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Formulas & Technical Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.blueLight, Color(0xFFE0F2FE)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hair Color Formula', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Current', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Base: 6N + 20vol developer\nHighlights: 8/1 + 7/0 (30vol)\nProcessing: 35 minutes', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.text)),
                const SizedBox(height: 8),
                const Text('Updated by Emma • 12 Nov 2025', style: TextStyle(fontSize: 10, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.greenLight, Color(0xFFDCFCE7)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Service Notes', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                SizedBox(height: 8),
                Text('Massage pressure: Medium-light\nSkin type: Sensitive, dry\nNail shape: Square, medium length', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- History Section ---
  Widget _buildHistorySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Appointment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 24),
          Stack(
            children: [
              Positioned(
                top: 0, bottom: 20, left: 6,
                child: Container(width: 2, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primary, AppColors.accent]))),
              ),
              Column(
                children: [
                  _buildTimelineItem(
                    title: 'Full Colour + Blowwave',
                    date: '15 Nov 2025',
                    staff: 'Emma',
                    duration: '90 mins',
                    notes: 'No irritation, client very happy with result',
                    products: "L'Oréal 6N, Olaplex treatment",
                    hasPhotos: true,
                  ),
                  _buildTimelineItem(
                    title: 'Relaxation Massage',
                    date: '10 Oct 2025',
                    staff: 'Sarah',
                    duration: '60 mins',
                    notes: 'Shoulder tension on left side, used eucalyptus oil',
                  ),
                  _buildTimelineItem(
                    title: 'Gel Manicure',
                    date: '25 Sep 2025',
                    staff: 'Lisa',
                    duration: '45 mins',
                    notes: 'Color: OPI "Ballet Slippers" #S86',
                    isLast: true,
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {},
              child: const Text('View Full History', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title, required String date, required String staff,
    required String duration, required String notes, String? products,
    bool hasPhotos = false, bool isLast = false
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 24, bottom: isLast ? 0 : 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -30, top: 0,
            child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 4)],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                    Text(date, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Done by: $staff', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(width: 16),
                    Text('Duration: $duration', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Notes: $notes', style: const TextStyle(fontSize: 12, color: AppColors.text)),
                if (products != null) ...[
                  const SizedBox(height: 4),
                  Text('Products used: $products', style: const TextStyle(fontSize: 12, color: AppColors.text)),
                ],
                if (hasPhotos) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                          child: const Center(child: Text('Before', style: TextStyle(fontSize: 10, color: AppColors.muted))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                          child: const Center(child: Text('After', style: TextStyle(fontSize: 10, color: AppColors.muted))),
                        ),
                      ),
                    ],
                  )
                ]
              ],
            ),
          )
        ],
      ),
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

// --- Helper: Back Chevron to match other pages ---
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

// --- Helper Buttons ---
class _GradientButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  const _GradientButton({required this.text, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _SecondaryButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Icon(FontAwesomeIcons.penToSquare, color: AppColors.primary, size: 16),
          ),
        ),
      ),
    );
  }
}


