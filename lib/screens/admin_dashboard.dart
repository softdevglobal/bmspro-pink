import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart' as profile_screen;

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
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFF8B5CF6);
  static const yellow = Color(0xFFFFD700);
}

class AdminDashboard extends StatefulWidget {
  final String role;
  final String? branchName;

  const AdminDashboard({
    super.key,
    required this.role,
    this.branchName,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loadingMetrics = true;

  double _totalRevenue = 0;
  int _bookingCount = 0;
  double _avgTicketValue = 0;
  double _staffUtilization = 0; // 0–1
  double _clientRetention = 0; // 0–1

  @override
  void initState() {
    super.initState();
    _loadOwnerAnalytics();
  }

  Future<void> _loadOwnerAnalytics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _loadingMetrics = false);
        return;
      }

      final qs = await FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerUid', isEqualTo: user.uid)
          .get();

      double totalRevenue = 0;
      int bookingCount = 0;
      final Set<String> staffIds = {};
      final Map<String, int> clientVisits = {};

      for (final doc in qs.docs) {
        final data = doc.data();

        // Only confirmed / completed bookings
        final status =
            (data['status'] ?? '').toString().toLowerCase().trim();
        if (status != 'confirmed' && status != 'completed') continue;

        bookingCount++;

        // Price
        double price = 0;
        final rawPrice = data['price'];
        if (rawPrice is num) {
          price = rawPrice.toDouble();
        } else if (rawPrice is String) {
          price = double.tryParse(rawPrice) ?? 0;
        }

        // If price not set, derive from services list if present
        if (price == 0 && data['services'] is List) {
          final list = data['services'] as List;
          for (final item in list) {
            if (item is Map && item['price'] != null) {
              final p = item['price'];
              if (p is num) {
                price += p.toDouble();
              } else if (p is String) {
                price += double.tryParse(p) ?? 0;
              }
            }
          }
        }

        totalRevenue += price;

        // Staff IDs for utilization
        final topStaff = data['staffId'];
        if (topStaff != null && topStaff.toString().isNotEmpty) {
          staffIds.add(topStaff.toString());
        }
        if (data['services'] is List) {
          for (final item in (data['services'] as List)) {
            if (item is Map && item['staffId'] != null) {
              final sid = item['staffId'].toString();
              if (sid.isNotEmpty) staffIds.add(sid);
            }
          }
        }

        // Client visits for retention
        final clientKeySource = data['customerUid'] ??
            data['clientEmail'] ??
            data['clientPhone'] ??
            data['client'];
        final clientKey = (clientKeySource ?? '').toString().trim();
        if (clientKey.isNotEmpty) {
          clientVisits[clientKey] = (clientVisits[clientKey] ?? 0) + 1;
        }
      }

      double avgTicket = 0;
      if (bookingCount > 0) {
        avgTicket = totalRevenue / bookingCount;
      }

      double utilization = 0;
      if (staffIds.isNotEmpty && bookingCount > 0) {
        // Simple heuristic: assume 40 ideal bookings per staff member
        final capacity = staffIds.length * 40;
        utilization = (bookingCount / capacity).clamp(0.0, 1.0);
      }

      double retention = 0;
      if (clientVisits.isNotEmpty) {
        final totalClients = clientVisits.length;
        final returningClients =
            clientVisits.values.where((visits) => visits > 1).length;
        retention = (returningClients / totalClients).clamp(0.0, 1.0);
      }

      if (!mounted) return;
      setState(() {
        _totalRevenue = totalRevenue;
        _bookingCount = bookingCount;
        _avgTicketValue = avgTicket;
        _staffUtilization = utilization;
        _clientRetention = retention;
        _loadingMetrics = false;
      });
    } catch (e) {
      debugPrint('Error loading owner analytics: $e');
      if (!mounted) return;
      setState(() {
        _loadingMetrics = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(16, 16, 16, 80), // Bottom padding for nav bar
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildKpiSection(),
            const SizedBox(height: 24),
            _buildRevenueChartSection(),
            const SizedBox(height: 24),
            _buildServiceBreakdownSection(),
            const SizedBox(height: 24),
            _buildStaffPerformanceSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    String adminLabel = 'Admin';
    final role = widget.role;
    if (role == 'salon_owner') {
      adminLabel = 'Salon Owner';
    } else if (role == 'salon_branch_admin') {
      if (widget.branchName != null && widget.branchName!.isNotEmpty) {
        adminLabel = '${widget.branchName} Admin';
      } else {
        adminLabel = 'Branch Admin';
      }
    }

    // Leading widget:
    // - For salon owners: profile icon button on the far left, then the
    //   "Dashboard" title/subtitle beside it.
    // - For others: just the title/ subtitle column.
    Widget leading;
    if (role == 'salon_owner') {
      leading = Row(
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: AppColors.background,
                      body: const profile_screen.ProfileScreen(
                        showBackButton: true,
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.08),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    FontAwesomeIcons.user,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              Text(
                'Analytics & insights',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      leading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          Text(
            'Analytics & insights',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.muted,
            ),
          ),
        ],
      );
    }

    // Trailing widget: role pill ("Salon Owner", "Branch Admin", etc.)
    final Widget trailing = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(FontAwesomeIcons.userTie,
              size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            adminLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            leading,
            trailing,
          ],
        ),
      ],
    );
  }

  Widget _buildKpiSection() {
    final totalRevenueLabel =
        _loadingMetrics ? '—' : '\$${_totalRevenue.toStringAsFixed(0)}';
    final staffUtilPercent = _loadingMetrics
        ? '—'
        : '${(_staffUtilization * 100).toStringAsFixed(0)}%';
    final clientRetentionPercent = _loadingMetrics
        ? '—'
        : '${(_clientRetention * 100).toStringAsFixed(0)}%';
    final avgTicketLabel =
        _loadingMetrics ? '—' : '\$${_avgTicketValue.toStringAsFixed(0)}';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Total Revenue',
                value: totalRevenueLabel,
                icon: FontAwesomeIcons.dollarSign,
                iconColor: AppColors.green,
                iconBg: AppColors.green.withOpacity(0.1),
                trend: '12%',
                trendUp: true,
                trendColor: AppColors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Staff Utilization',
                value: staffUtilPercent,
                icon: FontAwesomeIcons.users,
                iconColor: AppColors.blue,
                iconBg: AppColors.blue.withOpacity(0.1),
                progressBarValue:
                    _loadingMetrics ? 0.0 : _staffUtilization,
                progressBarColor: AppColors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Client Retention',
                value: clientRetentionPercent,
                icon: FontAwesomeIcons.heart,
                iconColor: AppColors.purple,
                iconBg: AppColors.purple.withOpacity(0.1),
                trend: clientRetentionPercent,
                trendUp: true, // Just showing value as pill
                trendColor: AppColors.purple,
                isPill: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Avg Ticket Value',
                value: avgTicketLabel,
                icon: FontAwesomeIcons.receipt,
                iconColor: AppColors.primary,
                iconBg: AppColors.primary.withOpacity(0.1),
                trend: '8%',
                trendUp: true,
                trendColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    String? trend,
    bool? trendUp,
    Color? trendColor,
    double? progressBarValue,
    Color? progressBarColor,
    bool isPill = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 14),
                ),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trendColor?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    children: [
                      if (!isPill && trendUp == true) ...[
                        Icon(FontAwesomeIcons.arrowUp, size: 10, color: trendColor),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        trend,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: trendColor,
                        ),
                      ),
                    ],
                  ),
                ),
              if (progressBarValue != null)
                Text(
                  value, // Show value in top right for progress bar card logic from design
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: progressBarColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (progressBarValue == null)
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          if (progressBarValue != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progressBarValue,
                backgroundColor: Colors.grey.shade200,
                color: progressBarColor,
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChartSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Trends',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const titles = ['Nov 1', '5', '10', '15', '20', '25', '30'];
                        if (value.toInt() >= 0 && value.toInt() < titles.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(titles[value.toInt()], style: const TextStyle(color: AppColors.muted, fontSize: 10)),
                          );
                        }
                        return const Text('');
                      },
                      interval: 1,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 8.5),
                      FlSpot(1, 9.2),
                      FlSpot(2, 10.8),
                      FlSpot(3, 12.4),
                      FlSpot(4, 11.9),
                      FlSpot(5, 13.2),
                      FlSpot(6, 12.45),
                    ],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.1),
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

  Widget _buildServiceBreakdownSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue by Service',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(color: AppColors.primary, value: 45, title: '', radius: 50),
                        PieChartSectionData(color: AppColors.primaryDark, value: 30, title: '', radius: 50),
                        PieChartSectionData(color: const Color(0xFFF472B6), value: 15, title: '', radius: 50),
                        PieChartSectionData(color: const Color(0xFFF9A8D4), value: 8, title: '', radius: 50),
                        PieChartSectionData(color: const Color(0xFFFBCFE8), value: 2, title: '', radius: 50),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(AppColors.primary, 'Hair Services (45%)'),
                    _buildLegendItem(AppColors.primaryDark, 'Nail Care (30%)'),
                    _buildLegendItem(const Color(0xFFF472B6), 'Massage (15%)'),
                    _buildLegendItem(const Color(0xFFF9A8D4), 'Facial (8%)'),
                    _buildLegendItem(const Color(0xFFFBCFE8), 'Retail (2%)'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffPerformanceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Performers',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          _buildStaffItem('Emma Watson', 'Senior Stylist', '3,420', '45 services', '4.9'),
          _buildStaffItem('Michael Chen', 'Hair Specialist', '2,890', '38 services', '4.8'),
          _buildStaffItem('Lisa Rodriguez', 'Nail Technician', '2,650', '52 services', '4.7'),
          _buildStaffItem('David Kim', 'Massage Therapist', '2,380', '28 services', '4.9'),
        ],
      ),
    );
  }

  Widget _buildStaffItem(String name, String role, String revenue, String services, String rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                child: Text(name[0], style: const TextStyle(color: AppColors.text)),
                // backgroundImage: NetworkImage(...), // Add real images if available
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$$revenue',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              Row(
                children: [
                  Text(
                    services,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(FontAwesomeIcons.solidStar, size: 10, color: AppColors.yellow),
                  const SizedBox(width: 2),
                  Text(
                    rating,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

