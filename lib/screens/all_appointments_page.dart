import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppColors {
  static const primary = Color(0xFFFF2D8F);
  static const accent = Color(0xFFFF6FB5);
  static const background = Color(0xFFFFF5FA);
  static const card = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF9E9E9E);
  static const border = Color(0xFFF2D2E9);
}

class AllAppointmentsPage extends StatelessWidget {
  const AllAppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_Appt> appts = const [
      _Appt('Massage 60min', '10:00 AM', FontAwesomeIcons.spa, [0xFF8B5CF6, 0xFF7C3AED]),
      _Appt('Facial 45min', '12:00 PM', FontAwesomeIcons.leaf, [0xFFEC4899, 0xFFDB2777]),
      _Appt('Nails 45min', '3:00 PM', FontAwesomeIcons.handSparkles, [0xFFFF6FB5, 0xFFFF2D8F]),
      _Appt('Massage 60min', '4:30 PM', FontAwesomeIcons.spa, [0xFF60A5FA, 0xFF3B82F6]),
      _Appt('Facial 30min', '6:00 PM', FontAwesomeIcons.leaf, [0xFF34D399, 0xFF10B981]),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: appts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _ApptTile(appt: appts[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(color: AppColors.background),
      child: Row(
        children: const [
          _BackChevron(),
          Expanded(
            child: Center(
              child: Text(
                'Appointments',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text),
              ),
            ),
          ),
          SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _BackChevron extends StatelessWidget {
  const _BackChevron();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: const Icon(FontAwesomeIcons.chevronLeft,
          size: 18, color: AppColors.text),
    );
  }
}

class _Appt {
  final String title;
  final String time;
  final IconData icon;
  final List<int> gradient;
  const _Appt(this.title, this.time, this.icon, this.gradient);
}

class _ApptTile extends StatelessWidget {
  final _Appt appt;
  const _ApptTile({required this.appt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                colors: [
                  Color(appt.gradient[0]),
                  Color(appt.gradient[1]),
                ],
              ),
            ),
            child: Center(
                child: Icon(appt.icon, color: Colors.white, size: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appt.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(appt.time,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(FontAwesomeIcons.chevronRight,
              size: 14, color: AppColors.muted),
        ],
      ),
    );
  }
}


