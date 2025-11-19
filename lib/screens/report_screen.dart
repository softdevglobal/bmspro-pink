import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class AppColors {
  static const primary = Color(0xFFFF2D8F);
  static const accent = Color(0xFFFF6FB5);
  static const background = Color(0xFFFFF5FA);
  static const card = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF9E9E9E);
  static const border = Color(0xFFF2D2E9);
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _selectedTab = 'day'; // 'day', 'week', 'month'

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTabs(),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _buildCurrentView(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40, height: 40),
          const Text(
            'Summary',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.text),
          ),
          _iconButton(FontAwesomeIcons.bell),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(icon, size: 16, color: AppColors.text)),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
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
          _buildTabBtn('Day', 'day'),
          _buildTabBtn('Week', 'week'),
          _buildTabBtn('Month', 'month'),
        ],
      ),
    );
  }

  Widget _buildTabBtn(String label, String id) {
    final isSelected = _selectedTab == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent])
                : null,
            color: isSelected ? null : Colors.transparent,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedTab) {
      case 'day':
        return _buildDayView();
      case 'week':
        return _buildWeekView();
      case 'month':
        return _buildMonthView();
      default:
        return _buildDayView();
    }
  }

  Widget _buildDayView() {
    return Column(
      key: const ValueKey('day'),
      children: [
        _buildSummaryHeader('Daily Summary', 'Tuesday, 17 March 2025'),
        const SizedBox(height: 24),
        _buildKpiGrid([
          _KpiData(FontAwesomeIcons.clock, '7h 45m', 'Hours Worked'),
          _KpiData(FontAwesomeIcons.circleCheck, '6', 'Tasks Completed'),
          _KpiData(FontAwesomeIcons.dollarSign, '\$85', 'Total Tips'),
          _KpiData(FontAwesomeIcons.star, '4.8', 'Rating'),
        ]),
        const SizedBox(height: 24),
        _buildNotesCard(),
        const SizedBox(height: 24),
        _buildDownloadBtn('Download Day PDF'),
      ],
    );
  }

  Widget _buildWeekView() {
    return Column(
      key: const ValueKey('week'),
      children: [
        _buildSummaryHeader('Week Summary', '10 → 17 March 2025'),
        const SizedBox(height: 24),
        _buildKpiGrid([
          _KpiData(FontAwesomeIcons.clock, '38h 12m', 'Total Hours'),
          _KpiData(FontAwesomeIcons.listCheck, '28', 'Tasks Completed'),
          _KpiData(FontAwesomeIcons.dollarSign, '\$360', 'Total Tips'),
          _KpiData(FontAwesomeIcons.star, '4.7', 'Avg Rating'),
        ]),
        const SizedBox(height: 24),
        _buildChartContainer('Hours per Day', _buildWeekChart()),
        const SizedBox(height: 24),
        _buildDownloadBtn('Download Week PDF'),
      ],
    );
  }

  Widget _buildMonthView() {
    return Column(
      key: const ValueKey('month'),
      children: [
        _buildSummaryHeader('Month Summary', 'March 2025'),
        const SizedBox(height: 24),
        _buildKpiGrid([
          _KpiData(FontAwesomeIcons.clock, '152h', 'Total Hours'),
          _KpiData(FontAwesomeIcons.listCheck, '118', 'Tasks Completed'),
          _KpiData(FontAwesomeIcons.dollarSign, '\$1,240', 'Total Tips'),
          _KpiData(FontAwesomeIcons.star, '4.75', 'Avg Rating'),
        ]),
        const SizedBox(height: 24),
        _buildChartContainer('Weekly Breakdown', _buildMonthChart()),
        const SizedBox(height: 24),
        _buildDownloadBtn('Download Month PDF'),
      ],
    );
  }

  Widget _buildSummaryHeader(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(List<_KpiData> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildKpiCard(items[index]);
      },
    );
  }

  Widget _buildKpiCard(_KpiData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent]),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Center(child: Icon(data.icon, color: Colors.white, size: 18)),
          ),
          Text(
            data.value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          SizedBox(height: 8),
          Text('Great work today! 🌸',
              style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _buildDownloadBtn(String text) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(FontAwesomeIcons.download,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartContainer(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 24),
          SizedBox(height: 250, child: chart),
        ],
      ),
    );
  }

  Widget _buildWeekChart() {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(days[value.toInt()],
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.muted)),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeGroupData(0, 7, AppColors.primary),
          _makeGroupData(1, 6, AppColors.accent),
          _makeGroupData(2, 5.5, AppColors.primary),
          _makeGroupData(3, 8, AppColors.accent),
          _makeGroupData(4, 5, AppColors.primary),
          _makeGroupData(5, 6.5, AppColors.accent),
          _makeGroupData(6, 0, Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _buildMonthChart() {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < 4) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Week ${value.toInt() + 1}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.muted)),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeGroupData(0, 32, AppColors.primary),
          _makeGroupData(1, 35, AppColors.accent),
          _makeGroupData(2, 38, AppColors.primary),
          _makeGroupData(3, 47, AppColors.accent),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 16,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 50,
            color: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }
}

class _KpiData {
  final IconData icon;
  final String value;
  final String label;
  _KpiData(this.icon, this.value, this.label);
}
