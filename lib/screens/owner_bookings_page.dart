import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class OwnerBookingsPage extends StatefulWidget {
  const OwnerBookingsPage({super.key});

  @override
  State<OwnerBookingsPage> createState() => _OwnerBookingsPageState();
}

class _OwnerBookingsPageState extends State<OwnerBookingsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

  // Mock booking data based on the HTML prototype
  final List<_Booking> _bookings = [
    _Booking(
      customerName: 'Sarah Johnson',
      email: 'sarah.j@email.com',
      avatarUrl:
          'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-5.jpg',
      status: 'confirmed',
      service: 'Hair Styling & Color',
      staff: 'Emma Wilson',
      dateTime: 'Dec 8, 2024 at 10:00 AM',
      duration: '2 hours',
      price: '\$150',
      icon: FontAwesomeIcons.scissors,
    ),
    _Booking(
      customerName: 'Michael Chen',
      email: 'mchen@email.com',
      avatarUrl:
          'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-2.jpg',
      status: 'pending',
      service: 'Mens Haircut',
      staff: 'David Brown',
      dateTime: 'Dec 8, 2024 at 11:30 AM',
      duration: '45 minutes',
      price: '\$45',
      icon: FontAwesomeIcons.scissors,
    ),
    _Booking(
      customerName: 'Jessica Martinez',
      email: 'jmartinez@email.com',
      avatarUrl:
          'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-7.jpg',
      status: 'confirmed',
      service: 'Manicure & Pedicure',
      staff: 'Sophie Taylor',
      dateTime: 'Dec 9, 2024 at 2:00 PM',
      duration: '1.5 hours',
      price: '\$85',
      icon: FontAwesomeIcons.handSparkles,
    ),
    _Booking(
      customerName: 'Robert Williams',
      email: 'rwilliams@email.com',
      avatarUrl:
          'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-3.jpg',
      status: 'completed',
      service: 'Facial Treatment',
      staff: 'Emma Wilson',
      dateTime: 'Dec 9, 2024 at 3:30 PM',
      duration: '1 hour',
      price: '\$120',
      icon: FontAwesomeIcons.spa,
    ),
    _Booking(
      customerName: 'Amanda Lee',
      email: 'alee@email.com',
      avatarUrl:
          'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-6.jpg',
      status: 'confirmed',
      service: 'Hair Extensions',
      staff: 'Sophie Taylor',
      dateTime: 'Dec 10, 2024 at 9:00 AM',
      duration: '3 hours',
      price: '\$350',
      icon: FontAwesomeIcons.wandMagicSparkles,
    ),
    _Booking(
      customerName: 'David Park',
      email: 'dpark@email.com',
      avatarUrl:
          'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-4.jpg',
      status: 'cancelled',
      service: 'Beard Trim & Shape',
      staff: 'David Brown',
      dateTime: 'Dec 10, 2024 at 1:00 PM',
      duration: '30 minutes',
      price: '\$35',
      icon: FontAwesomeIcons.scissors,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFFFF2D8F);
    const Color background = Color(0xFFFFF5FA);

    final filtered = _bookings.where((b) {
      final matchesStatus =
          _statusFilter == 'all' ? true : b.status == _statusFilter;
      final term = _searchController.text.trim().toLowerCase();
      if (term.isEmpty) return matchesStatus;
      final inText =
          '${b.customerName} ${b.email} ${b.service} ${b.staff}'.toLowerCase();
      return matchesStatus && inText.contains(term);
    }).toList();

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: background,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Bookings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage appointments',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text(
                        'Export',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Expanded(
                          child: _StatCard(
                            label: 'Total',
                            value: '18',
                            color: Colors.black87,
                            background: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Confirmed',
                            value: '12',
                            color: Color(0xFF166534),
                            background: Color(0xFFD1FAE5),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Pending',
                            value: '4',
                            color: Color(0xFF92400E),
                            background: Color(0xFFFEEFC3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Expanded(
                          child: _StatCard(
                            label: 'Completed',
                            value: '8',
                            color: Color(0xFF1D4ED8),
                            background: Color(0xFFDBEAFE),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Revenue',
                            value: '\$2,840',
                            color: Color(0xFF5B21B6),
                            background: Color(0xFFEDE9FE),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search bookings...',
                          prefixIcon: const Icon(Icons.search,
                              size: 18, color: Color(0xFF9CA3AF)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.filter_alt,
                              size: 18, color: Color(0xFF9CA3AF)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: primary),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Statuses'),
                          ),
                          DropdownMenuItem(
                            value: 'confirmed',
                            child: Text('Confirmed'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Cancelled'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _statusFilter = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bookings list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: filtered
                      .map((b) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BookingCard(booking: b),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: background.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _Booking {
  final String customerName;
  final String email;
  final String avatarUrl;
  final String status; // confirmed, pending, completed, cancelled
  final String service;
  final String staff;
  final String dateTime;
  final String duration;
  final String price;
  final IconData icon;

  const _Booking({
    required this.customerName,
    required this.email,
    required this.avatarUrl,
    required this.status,
    required this.service,
    required this.staff,
    required this.dateTime,
    required this.duration,
    required this.price,
    required this.icon,
  });
}

class _BookingCard extends StatelessWidget {
  final _Booking booking;

  const _BookingCard({required this.booking});

  Color _statusBg(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFFD1FAE5);
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'completed':
        return const Color(0xFFDBEAFE);
      case 'cancelled':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF166534);
      case 'pending':
        return const Color(0xFF92400E);
      case 'completed':
        return const Color(0xFF1D4ED8);
      case 'cancelled':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF4B5563);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBg = _statusBg(booking.status);
    final statusColor = _statusColor(booking.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: NetworkImage(booking.avatarUrl),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        booking.email,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _capitalise(booking.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(
            icon: booking.icon,
            text: booking.service,
          ),
          _infoRow(
            icon: FontAwesomeIcons.user,
            text: 'with ${booking.staff}',
          ),
          _infoRow(
            icon: FontAwesomeIcons.calendar,
            text: booking.dateTime,
          ),
          _infoRow(
            icon: FontAwesomeIcons.clock,
            text: booking.duration,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                booking.price,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: booking.status == 'cancelled'
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFFFF2D8F),
                  decoration: booking.status == 'cancelled'
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              Row(
                children: const [
                  _ActionIcon(
                    icon: FontAwesomeIcons.penToSquare,
                    background: Color(0xFFE0EDFF),
                    color: Color(0xFF2563EB),
                  ),
                  SizedBox(width: 6),
                  _ActionIcon(
                    icon: FontAwesomeIcons.trash,
                    background: Color(0xFFFEE2E2),
                    color: Color(0xFFB91C1C),
                  ),
                  SizedBox(width: 6),
                  _ActionIcon(
                    icon: FontAwesomeIcons.ellipsisVertical,
                    background: Color(0xFFF3F4F6),
                    color: Color(0xFF4B5563),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalise(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color color;

  const _ActionIcon({
    required this.icon,
    required this.background,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}