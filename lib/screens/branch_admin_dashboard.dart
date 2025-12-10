import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
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
  static const orange = Color(0xFFF97316);
}

class BranchAdminDashboard extends StatefulWidget {
  final String branchName;

  const BranchAdminDashboard({super.key, required this.branchName});

  @override
  State<BranchAdminDashboard> createState() => _BranchAdminDashboardState();
}

class _BranchAdminDashboardState extends State<BranchAdminDashboard> {
  bool _loading = true;
  String? _branchId;
  String? _ownerUid;

  // KPI Data
  double _totalRevenue = 0;
  double _lastMonthRevenue = 0;
  int _totalBookings = 0;
  int _completedBookings = 0;
  int _totalClients = 0;
  int _returningClients = 0;
  
  // Staff data
  List<Map<String, dynamic>> _staffPerformance = [];
  
  // Service breakdown
  Map<String, double> _serviceRevenue = {};
  
  // Revenue by day (last 30 days)
  List<double> _dailyRevenue = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Get user's branch and owner info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() => _loading = false);
        return;
      }

      final userData = userDoc.data()!;
      _branchId = userData['branchId']?.toString();
      _ownerUid = userData['ownerUid']?.toString() ?? user.uid;

      if (_branchId == null || _branchId!.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      // Fetch all bookings for this branch
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final sixtyDaysAgo = now.subtract(const Duration(days: 60));

      final bookingsSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('ownerUid', isEqualTo: _ownerUid)
          .where('branchId', isEqualTo: _branchId)
          .get();

      // Process bookings
      double totalRevenue = 0;
      double lastMonthRevenue = 0;
      int completedBookings = 0;
      Set<String> uniqueClients = {};
      Map<String, int> clientBookingCount = {};
      Map<String, double> serviceRevenue = {};
      Map<String, double> staffRevenue = {};
      Map<String, int> staffBookingCount = {};
      List<double> dailyRevenue = List.filled(30, 0);

      for (var doc in bookingsSnap.docs) {
        final data = doc.data();
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        final status = (data['status'] ?? '').toString().toLowerCase();
        final dateStr = (data['date'] ?? '').toString();
        final client = (data['client'] ?? '').toString();
        final serviceName = (data['serviceName'] ?? '').toString();
        final staffName = (data['staffName'] ?? 'Unassigned').toString();

        // Parse date
        DateTime? bookingDate;
        try {
          if (dateStr.isNotEmpty) {
            bookingDate = DateTime.parse(dateStr);
          }
        } catch (_) {}

        // Count completed bookings
        if (status == 'completed' || status == 'confirmed') {
          completedBookings++;
          totalRevenue += price;

          // Track client
          if (client.isNotEmpty) {
            uniqueClients.add(client.toLowerCase());
            clientBookingCount[client.toLowerCase()] = 
                (clientBookingCount[client.toLowerCase()] ?? 0) + 1;
          }

          // Service revenue
          if (serviceName.isNotEmpty) {
            // Split if multiple services
            for (var svc in serviceName.split(',')) {
              final svcName = svc.trim();
              if (svcName.isNotEmpty) {
                serviceRevenue[svcName] = (serviceRevenue[svcName] ?? 0) + (price / serviceName.split(',').length);
              }
            }
          }

          // Staff performance
          if (staffName.isNotEmpty && staffName != 'Any Available' && staffName != 'Multiple Staff') {
            staffRevenue[staffName] = (staffRevenue[staffName] ?? 0) + price;
            staffBookingCount[staffName] = (staffBookingCount[staffName] ?? 0) + 1;
          }

          // Daily revenue (last 30 days)
          if (bookingDate != null && bookingDate.isAfter(thirtyDaysAgo)) {
            final dayIndex = now.difference(bookingDate).inDays;
            if (dayIndex >= 0 && dayIndex < 30) {
              dailyRevenue[29 - dayIndex] += price;
            }
          }

          // Last month revenue (30-60 days ago)
          if (bookingDate != null && 
              bookingDate.isAfter(sixtyDaysAgo) && 
              bookingDate.isBefore(thirtyDaysAgo)) {
            lastMonthRevenue += price;
          }
        }
      }

      // Calculate returning clients
      int returningClients = clientBookingCount.values.where((c) => c > 1).length;

      // Build staff performance list
      List<Map<String, dynamic>> staffPerformance = [];
      staffRevenue.forEach((name, revenue) {
        staffPerformance.add({
          'name': name,
          'revenue': revenue,
          'bookings': staffBookingCount[name] ?? 0,
        });
      });
      staffPerformance.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

      if (mounted) {
        setState(() {
          _totalRevenue = totalRevenue;
          _lastMonthRevenue = lastMonthRevenue;
          _totalBookings = bookingsSnap.docs.length;
          _completedBookings = completedBookings;
          _totalClients = uniqueClients.length;
          _returningClients = returningClients;
          _serviceRevenue = serviceRevenue;
          _staffPerformance = staffPerformance.take(5).toList();
          _dailyRevenue = dailyRevenue;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  double get _revenueGrowth {
    if (_lastMonthRevenue == 0) return 0;
    return ((_totalRevenue - _lastMonthRevenue) / _lastMonthRevenue) * 100;
  }

  double get _clientRetention {
    if (_totalClients == 0) return 0;
    return (_returningClients / _totalClients) * 100;
  }

  double get _avgTicketValue {
    if (_completedBookings == 0) return 0;
    return _totalRevenue / _completedBookings;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
              const SizedBox(height: 24),
              _buildInsightsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Profile button + Dashboard title
            Expanded(
              child: Row(
                children: [
                  GestureDetector(
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.15),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 12,
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
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
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
                  ),
                ],
              ),
            ),
            // Logged in admin name on the right
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FontAwesomeIcons.userTie, size: 12, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    widget.branchName.isNotEmpty ? '${widget.branchName} Admin' : 'Branch Admin',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiSection() {
    final growthPercent = _revenueGrowth;
    final isPositiveGrowth = growthPercent >= 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Total Revenue',
                value: '\$${_totalRevenue.toStringAsFixed(0)}',
                icon: FontAwesomeIcons.dollarSign,
                iconColor: AppColors.green,
                iconBg: AppColors.green.withOpacity(0.1),
                trend: '${isPositiveGrowth ? '+' : ''}${growthPercent.toStringAsFixed(0)}%',
                trendUp: isPositiveGrowth,
                trendColor: isPositiveGrowth ? AppColors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Bookings',
                value: '$_completedBookings',
                icon: FontAwesomeIcons.calendarCheck,
                iconColor: AppColors.purple,
                iconBg: AppColors.purple.withOpacity(0.1),
                subtitle: 'of $_totalBookings total',
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
                value: '${_clientRetention.toStringAsFixed(0)}%',
                icon: FontAwesomeIcons.heart,
                iconColor: AppColors.blue,
                iconBg: AppColors.blue.withOpacity(0.1),
                subtitle: '$_returningClients returning',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Avg Ticket Value',
                value: '\$${_avgTicketValue.toStringAsFixed(0)}',
                icon: FontAwesomeIcons.ticket,
                iconColor: AppColors.orange,
                iconBg: AppColors.orange.withOpacity(0.1),
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
    String? subtitle,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trendColor?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: trendColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueChartSection() {
    // Convert daily revenue to chart spots (sample every 5 days for cleaner chart)
    List<FlSpot> spots = [];
    for (int i = 0; i < 7; i++) {
      final dayIndex = i * 4; // 0, 4, 8, 12, 16, 20, 24
      if (dayIndex < _dailyRevenue.length) {
        // Sum revenue for a few days around this point
        double sum = 0;
        for (int j = dayIndex; j < dayIndex + 4 && j < _dailyRevenue.length; j++) {
          sum += _dailyRevenue[j];
        }
        spots.add(FlSpot(i.toDouble(), sum / 100)); // Scale down for chart
      }
    }

    if (spots.isEmpty) {
      spots = [const FlSpot(0, 0), const FlSpot(1, 0)];
    }

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
            children: [
              const Icon(FontAwesomeIcons.chartLine, color: AppColors.green, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Revenue Trends (Last 30 Days)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
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
                        const titles = ['Day 1', '5', '10', '15', '20', '25', '30'];
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
                    spots: spots,
                    isCurved: true,
                    color: AppColors.green,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.green.withOpacity(0.1),
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
    if (_serviceRevenue.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(FontAwesomeIcons.chartPie, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Revenue by Service Type',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('No service data available', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }

    // Calculate percentages
    final total = _serviceRevenue.values.fold(0.0, (a, b) => a + b);
    final sortedServices = _serviceRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topServices = sortedServices.take(4).toList();

    final colors = [
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
    ];

    List<PieChartSectionData> sections = [];
    List<Widget> legends = [];

    for (int i = 0; i < topServices.length; i++) {
      final entry = topServices[i];
      final percent = (entry.value / total) * 100;
      sections.add(PieChartSectionData(
        color: colors[i % colors.length],
        value: percent,
        title: '${percent.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      legends.add(_buildLegendItem(colors[i % colors.length], entry.key));
    }

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
            children: [
              const Icon(FontAwesomeIcons.chartPie, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Revenue by Service Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: legends,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text.length > 15 ? '${text.substring(0, 15)}...' : text,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
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
          Row(
            children: [
              const Icon(FontAwesomeIcons.trophy, color: AppColors.yellow, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Top Performing Staff',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_staffPerformance.isEmpty)
            const Text('No staff performance data', style: TextStyle(color: AppColors.muted))
          else
            ...List.generate(_staffPerformance.length, (index) {
              final staff = _staffPerformance[index];
              final isFirst = index == 0;
              return Padding(
                padding: EdgeInsets.only(bottom: index < _staffPerformance.length - 1 ? 12 : 0),
                child: _buildStaffItem(
                  staff['name'],
                  '\$${(staff['revenue'] as double).toStringAsFixed(0)} • ${staff['bookings']} services',
                  index + 1,
                  isFirst ? Colors.yellow.shade50 : Colors.grey.shade50,
                  isFirst ? Colors.yellow.shade100 : Colors.transparent,
                  isFirst ? AppColors.yellow : Colors.grey.shade400,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStaffItem(
      String name, String details, int rank, Color bgColor, Color borderColor, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor == Colors.transparent ? Colors.transparent : borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.text)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.length > 20 ? '${name.substring(0, 20)}...' : name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    details,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    // Generate dynamic insights based on data
    List<Map<String, dynamic>> insights = [];

    // Revenue insight
    if (_revenueGrowth > 0) {
      insights.add({
        'title': 'Revenue Growth',
        'description': '${_revenueGrowth.toStringAsFixed(0)}% increase compared to last month',
        'icon': FontAwesomeIcons.arrowUp,
        'iconColor': Colors.green.shade500,
        'bgColor': Colors.green.shade50,
      });
    } else if (_revenueGrowth < 0) {
      insights.add({
        'title': 'Revenue Decline',
        'description': '${_revenueGrowth.abs().toStringAsFixed(0)}% decrease compared to last month',
        'icon': FontAwesomeIcons.arrowDown,
        'iconColor': Colors.red.shade500,
        'bgColor': Colors.red.shade50,
      });
    }

    // Top service insight
    if (_serviceRevenue.isNotEmpty) {
      final topService = _serviceRevenue.entries.reduce((a, b) => a.value > b.value ? a : b);
      insights.add({
        'title': 'Top Service',
        'description': '${topService.key} generates most revenue',
        'icon': FontAwesomeIcons.star,
        'iconColor': Colors.blue.shade500,
        'bgColor': Colors.blue.shade50,
      });
    }

    // Client retention insight
    if (_clientRetention > 50) {
      insights.add({
        'title': 'Great Retention',
        'description': '${_clientRetention.toStringAsFixed(0)}% of clients are returning customers',
        'icon': FontAwesomeIcons.heart,
        'iconColor': Colors.pink.shade500,
        'bgColor': Colors.pink.shade50,
      });
    } else if (_totalClients > 0) {
      insights.add({
        'title': 'Retention Opportunity',
        'description': 'Consider loyalty programs to increase repeat visits',
        'icon': FontAwesomeIcons.circleExclamation,
        'iconColor': Colors.orange.shade500,
        'bgColor': Colors.orange.shade50,
      });
    }

    if (insights.isEmpty) {
      insights.add({
        'title': 'Getting Started',
        'description': 'Complete more bookings to see insights',
        'icon': FontAwesomeIcons.lightbulb,
        'iconColor': Colors.blue.shade500,
        'bgColor': Colors.blue.shade50,
      });
    }

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
            children: [
              const Icon(FontAwesomeIcons.lightbulb, color: AppColors.blue, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Business Insights',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.asMap().entries.map((entry) {
            final index = entry.key;
            final insight = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index < insights.length - 1 ? 12 : 0),
              child: _buildInsightItem(
                insight['title'],
                insight['description'],
                insight['icon'],
                insight['iconColor'],
                insight['bgColor'],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInsightItem(
      String title, String description, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
