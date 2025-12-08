import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Live booking data from Firestore (bookings + bookingRequests for this owner)
  List<_Booking> _bookings = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bookingsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bookingRequestsSub;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _listenToBookings();
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _bookingRequestsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToBookings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = "Not signed in";
      });
      return;
    }

    final uid = user.uid;

    List<_Booking> bookingsData = [];
    List<_Booking> bookingRequestsData = [];

    void mergeAndSet() {
      // Merge and deduplicate by an internal key (client+date+time+service as fallback)
      final Map<String, _Booking> map = {};
      for (final b in bookingsData) {
        map[b.mergeKey] = b;
      }
      for (final b in bookingRequestsData) {
        map[b.mergeKey] = b;
      }
      final merged = map.values.toList()
        ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

      if (mounted) {
        setState(() {
          _bookings = merged;
          _loading = false;
        });
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    _bookingsSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .listen(
      (snap) {
        bookingsData = snap.docs.map(_Booking.fromDoc).toList();
        mergeAndSet();
      },
      onError: (e) {
        if (mounted) {
          setState(() => _error ??= e.toString());
        }
      },
    );

    _bookingRequestsSub = FirebaseFirestore.instance
        .collection('bookingRequests')
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .listen(
      (snap) {
        bookingRequestsData = snap.docs.map(_Booking.fromDoc).toList();
        mergeAndSet();
      },
      onError: (e) {
        if (mounted) {
          setState(() => _error ??= e.toString());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFFFF2D8F);
    const Color background = Color(0xFFFFF5FA);

    // Aggregate stats from all bookings (not filtered by search)
    final totalCount = _bookings.length;
    final confirmedCount =
        _bookings.where((b) => b.status == 'confirmed').length;
    final pendingCount = _bookings.where((b) => b.status == 'pending').length;
    final completedCount =
        _bookings.where((b) => b.status == 'completed').length;

    double revenue = 0.0;
    for (final b in _bookings) {
      if (b.status == 'confirmed' || b.status == 'completed') {
        revenue += b.priceValue;
      }
    }

    final revenueLabel =
        revenue > 0 ? '\$${revenue.toStringAsFixed(0)}' : '\$0';

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
                child: const Center(
                  child: Text(
                    'Bookings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Total',
                            value: '$totalCount',
                            color: Colors.black87,
                            background: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Confirmed',
                            value: '$confirmedCount',
                            color: const Color(0xFF166534),
                            background: const Color(0xFFD1FAE5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Pending',
                            value: '$pendingCount',
                            color: const Color(0xFF92400E),
                            background: const Color(0xFFFEEFC3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Completed',
                            value: '$completedCount',
                            color: const Color(0xFF1D4ED8),
                            background: const Color(0xFFDBEAFE),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Revenue',
                            value: revenueLabel,
                            color: const Color(0xFF5B21B6),
                            background: const Color(0xFFEDE9FE),
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
                            value: 'pending',
                            child: Text('Booking Requests'),
                          ),
                          DropdownMenuItem(
                            value: 'confirmed',
                            child: Text('Confirmed Bookings'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed Bookings'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Cancelled Bookings'),
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
  final String mergeKey;
  final DateTime sortKey;
  final String customerName;
  final String email;
  final String avatarUrl;
  final String status; // confirmed, pending, completed, cancelled
  final String service;
  final String staff;
  final String dateTime;
  final String duration;
  final String price;
  final double priceValue;
  final IconData icon;

  const _Booking({
    required this.mergeKey,
    required this.sortKey,
    required this.customerName,
    required this.email,
    required this.avatarUrl,
    required this.status,
    required this.service,
    required this.staff,
    required this.dateTime,
    required this.duration,
    required this.price,
    required this.priceValue,
    required this.icon,
  });

  // Build a booking model from a Firestore document
  static _Booking fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final client = (data['client'] ?? 'Walk-in').toString();
    final email = (data['clientEmail'] ?? '').toString();
    final staffName = (data['staffName'] ?? 'Any staff').toString();
    String serviceName = (data['serviceName'] ?? '').toString();
    if (serviceName.isEmpty && data['services'] is List) {
      final list = data['services'] as List;
      if (list.isNotEmpty && list.first is Map) {
        serviceName =
            (list.first['name'] ?? 'Service').toString();
      }
    }
    if (serviceName.isEmpty) serviceName = 'Service';

    final date = (data['date'] ?? '').toString(); // YYYY-MM-DD
    final time = (data['time'] ?? '').toString(); // HH:mm
    String dateTimeLabel;
    DateTime sortKey;
    try {
      if (date.isNotEmpty && time.isNotEmpty) {
        final parts = date.split('-');
        final tParts = time.split(':');
        sortKey = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
          int.parse(tParts[0]),
          tParts.length > 1 ? int.parse(tParts[1]) : 0,
        );
        dateTimeLabel = '$date at $time';
      } else {
        sortKey = DateTime.fromMillisecondsSinceEpoch(0);
        dateTimeLabel = (date + (time.isNotEmpty ? ' $time' : '')).trim();
      }
    } catch (_) {
      sortKey = DateTime.fromMillisecondsSinceEpoch(0);
      dateTimeLabel = (date + (time.isNotEmpty ? ' $time' : '')).trim();
    }

    final durationMinutes = (data['duration'] ?? 0);
    String durationLabel = '';
    if (durationMinutes is num && durationMinutes > 0) {
      if (durationMinutes >= 60 && durationMinutes % 60 == 0) {
        final hours = durationMinutes ~/ 60;
        durationLabel = '$hours hour${hours > 1 ? 's' : ''}';
      } else {
        durationLabel = '${durationMinutes.toString()} minutes';
      }
    }

    final rawPrice = (data['price'] ?? 0);
    double priceValue = 0;
    if (rawPrice is num) {
      priceValue = rawPrice.toDouble();
    } else {
      priceValue = double.tryParse(rawPrice.toString()) ?? 0.0;
    }
    final priceLabel =
        priceValue > 0 ? '\$${priceValue.toStringAsFixed(0)}' : '\$0';

    String status =
        (data['status'] ?? 'pending').toString().toLowerCase();
    if (status == 'canceled') status = 'cancelled';

    final avatarUrl = (data['avatarUrl'] ??
            'https://ui-avatars.com/api/?background=FF2D8F&color=fff&name=${Uri.encodeComponent(client)}')
        .toString();

    IconData icon = FontAwesomeIcons.scissors;
    final serviceLower = serviceName.toLowerCase();
    if (serviceLower.contains('nail')) {
      icon = FontAwesomeIcons.handSparkles;
    } else if (serviceLower.contains('facial') ||
        serviceLower.contains('spa')) {
      icon = FontAwesomeIcons.spa;
    } else if (serviceLower.contains('massage')) {
      icon = FontAwesomeIcons.spa;
    } else if (serviceLower.contains('extension')) {
      icon = FontAwesomeIcons.wandMagicSparkles;
    }

    final mergeKey =
        doc.id.isNotEmpty ? doc.id : '$client|$date|$time|$serviceName';

    return _Booking(
      mergeKey: mergeKey,
      sortKey: sortKey,
      customerName: client,
      email: email,
      avatarUrl: avatarUrl,
      status: status,
      service: serviceName,
      staff: staffName,
      dateTime: dateTimeLabel,
      duration: durationLabel,
      price: priceLabel,
      priceValue: priceValue,
      icon: icon,
    );
  }
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
                children: [
                  _ActionIcon(
                    icon: FontAwesomeIcons.eye,
                    background: const Color(0xFFE0EDFF),
                    color: const Color(0xFF2563EB),
                    onTap: () => _showBookingDetails(context, booking),
                  ),
                  const SizedBox(width: 6),
                  const _ActionIcon(
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

  void _showBookingDetails(BuildContext context, _Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF5FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Header with Avatar and Status
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(booking.avatarUrl),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            booking.customerName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBg(booking.status),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _capitalise(booking.status),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(booking.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Details Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _detailRow(
                            'Service',
                            booking.service,
                            booking.icon,
                            const Color(0xFFFF2D8F),
                          ),
                          const Divider(height: 24),
                          _detailRow(
                            'Staff',
                            booking.staff,
                            FontAwesomeIcons.userTie,
                            const Color(0xFF8B5CF6),
                          ),
                          const Divider(height: 24),
                          _detailRow(
                            'Date & Time',
                            booking.dateTime,
                            FontAwesomeIcons.calendarCheck,
                            const Color(0xFF10B981),
                          ),
                          const Divider(height: 24),
                          _detailRow(
                            'Duration',
                            booking.duration,
                            FontAwesomeIcons.hourglassHalf,
                            const Color(0xFFF59E0B),
                          ),
                          const Divider(height: 24),
                          _detailRow(
                            'Price',
                            booking.price,
                            FontAwesomeIcons.tag,
                            const Color(0xFFEF4444),
                            isPrice: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // Close Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D8F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon, Color color,
      {bool isPrice = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isPrice ? const Color(0xFFFF2D8F) : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
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
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
