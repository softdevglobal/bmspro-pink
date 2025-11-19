import 'package:flutter/material.dart';
import '../widgets/pink_bottom_nav.dart';
import '../widgets/primary_gradient_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _HomeDashboard(),
      const _PlaceholderPage(title: 'Schedule'),
      const _PlaceholderPage(title: 'Clients'),
      const _PlaceholderPage(title: 'Reports'),
      const _PlaceholderPage(title: 'Settings'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5FA),
      body: pages[_index],
      bottomNavigationBar: PinkBottomNav(
        currentIndex: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color accent = Theme.of(context).colorScheme.secondary;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Creative gradient header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-5.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Hi Emma',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          SizedBox(height: 2),
                          Text('Tuesday, 17 March',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: const [
                      Icon(Icons.notifications_none_rounded,
                          color: Colors.white),
                      Positioned(
                        right: -1,
                        top: -1,
                        child: CircleAvatar(
                            radius: 4, backgroundColor: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.08),
                          blurRadius: 40,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE5ED),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.schedule_rounded,
                              color: Color(0xFFFF2D8F)),
                        ),
                        const SizedBox(height: 10),
                        const Text('You are: CLOCKED OUT',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text('Ready to start your day?',
                            style: TextStyle(color: Color(0xFF9E9E9E))),
                        const SizedBox(height: 8),
                        PrimaryGradientButton(
                          label: 'Clock In',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.08),
                          blurRadius: 40,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Today\'s Appointments',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text('3',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        _AppointmentTile(
                          color: Colors.purple,
                          title: 'Massage 60min',
                          time: '10:00 AM',
                          trailing: const Text('Next',
                              style: TextStyle(
                                  color: Color(0xFFFF2D8F),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                        const SizedBox(height: 8),
                        _AppointmentTile(
                          color: Colors.pink,
                          title: 'Facial 45min',
                          time: '12:00 PM',
                        ),
                        const SizedBox(height: 8),
                        _AppointmentTile(
                          color: accent,
                          title: 'Nails 45min',
                          time: '3:00 PM',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {},
                          child: const Text('View All Appointments'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Quick Actions',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      Expanded(
                          child: _QuickAction(
                              icon: Icons.task_alt_rounded,
                              colors: [Colors.blue, Colors.indigo],
                              label: 'My Tasks')),
                      SizedBox(width: 10),
                      Expanded(
                          child: _QuickAction(
                              icon: Icons.calendar_month_rounded,
                              colors: [Colors.green, Colors.teal],
                              label: 'Calendar')),
                      SizedBox(width: 10),
                      Expanded(
                          child: _QuickAction(
                              icon: Icons.person_rounded,
                              colors: [Color(0xFFFF2D8F), Color(0xFFFF6FB5)],
                              label: 'Profile')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final Color color;
  final String title;
  final String time;
  final Widget? trailing;
  const _AppointmentTile({
    required this.color,
    required this.title,
    required this.time,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [color.withOpacity(0.6), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.spa_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(time,
                    style: const TextStyle(
                        color: Color(0xFF9E9E9E), fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final String label;
  const _QuickAction(
      {required this.icon, required this.colors, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: colors),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title));
  }
}
