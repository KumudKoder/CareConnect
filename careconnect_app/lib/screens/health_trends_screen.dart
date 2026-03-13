import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AppColors {
  static const Color primary = Color(0xFF00897B);
  static const Color secondary = Color(0xFF6C5CE7);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color background = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6C757D);
}

class HealthTrendsScreen extends StatefulWidget {
  const HealthTrendsScreen({super.key});

  @override
  State<HealthTrendsScreen> createState() => _HealthTrendsScreenState();
}

class _HealthTrendsScreenState extends State<HealthTrendsScreen> {
  String _selectedPeriod = '30 days';
  final List<String> _periods = ['7 days', '30 days', '90 days'];

  // Mock BP data (systolic)
  final List<double> _bpSystolic = [130, 125, 140, 135, 128, 145, 138, 132, 142, 136, 130, 140];
  final List<double> _bpDiastolic = [85, 82, 90, 88, 84, 92, 86, 84, 90, 87, 83, 88];

  // Mock blood sugar data
  final List<double> _sugarData = [110, 105, 120, 95, 108, 115, 100, 112, 98, 106, 102, 108];

  // Mock weight data
  final List<double> _weightData = [77, 76.5, 76.8, 76.2, 76, 75.5, 75.8, 75.3, 75, 75.2, 74.8, 75];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Health Trends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(icon: const Icon(Icons.share, color: AppColors.textPrimary, size: 20), onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📤 Share with Doctor — coming soon!')));
          }),
          IconButton(icon: const Icon(Icons.download, color: AppColors.textPrimary, size: 20), onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📥 Export Data — coming soon!')));
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Period selector
            _buildPeriodSelector(),
            const SizedBox(height: 20),

            // BP Chart
            _buildChartCard(
              title: '📈 Blood Pressure',
              status: _getBPStatus(),
              statusColor: _getBPStatusColor(),
              trend: '↗️ Slightly rising',
              chart: _buildBPChart(),
              details: 'Average: ${(_bpSystolic.reduce((a, b) => a + b) / _bpSystolic.length).toStringAsFixed(0)}/${(_bpDiastolic.reduce((a, b) => a + b) / _bpDiastolic.length).toStringAsFixed(0)} mmHg',
            ),
            const SizedBox(height: 16),

            // Blood Sugar Chart
            _buildChartCard(
              title: '🩸 Blood Sugar',
              status: '✓ Controlled',
              statusColor: AppColors.success,
              trend: '→ Stable',
              chart: _buildSugarChart(),
              details: 'Average: ${(_sugarData.reduce((a, b) => a + b) / _sugarData.length).toStringAsFixed(0)} mg/dl',
            ),
            const SizedBox(height: 16),

            // Weight Chart
            _buildChartCard(
              title: '⚖️ Weight',
              status: '↓ Decreasing',
              statusColor: AppColors.success,
              trend: '-2 kg ⬇️ Good!',
              chart: _buildWeightChart(),
              details: 'Current: ${_weightData.last} kg | Target: 72 kg',
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📥 Data exported!')));
                    },
                    icon: const Icon(Icons.download, color: Colors.white, size: 18),
                    label: const Text('Export Data', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📤 Shared with Dr. Sharma!')));
                    },
                    icon: const Icon(Icons.share, color: Colors.white, size: 18),
                    label: const Text('Share with Doctor', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: _periods.map((period) {
        final selected = period == _selectedPeriod;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPeriod = period),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300),
              ),
              child: Center(
                child: Text(period, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String status,
    required Color statusColor,
    required String trend,
    required Widget chart,
    required String details,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Text(trend, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(height: 180, child: chart),
          const SizedBox(height: 12),
          Text(details, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _getBPStatus() {
    double avg = _bpSystolic.reduce((a, b) => a + b) / _bpSystolic.length;
    if (avg < 120) return '✓ Normal';
    if (avg < 140) return '⚠️ Elevated';
    return '❌ High';
  }

  Color _getBPStatusColor() {
    double avg = _bpSystolic.reduce((a, b) => a + b) / _bpSystolic.length;
    if (avg < 120) return AppColors.success;
    if (avg < 140) return AppColors.warning;
    return AppColors.accent;
  }

  Widget _buildBPChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 35, interval: 20,
              getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 60,
        maxY: 160,
        lineBarsData: [
          // Systolic
          LineChartBarData(
            spots: _bpSystolic.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: AppColors.accent,
            barWidth: 3,
            dotData: FlDotData(show: true, getDotPainter: (s, v, b, i) => FlDotCirclePainter(radius: 3, color: AppColors.accent, strokeWidth: 0)),
            belowBarData: BarAreaData(show: true, color: AppColors.accent.withValues(alpha: 0.1)),
          ),
          // Diastolic
          LineChartBarData(
            spots: _bpDiastolic.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: FlDotData(show: true, getDotPainter: (s, v, b, i) => FlDotCirclePainter(radius: 3, color: AppColors.primary, strokeWidth: 0)),
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              '${s.y.toInt()} mmHg',
              TextStyle(color: s.bar.color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSugarChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true, drawVerticalLine: false, horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 35, interval: 20,
              getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 70,
        maxY: 140,
        lineBarsData: [
          LineChartBarData(
            spots: _sugarData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: AppColors.secondary,
            barWidth: 3,
            dotData: FlDotData(show: true, getDotPainter: (s, v, b, i) => FlDotCirclePainter(radius: 3, color: AppColors.secondary, strokeWidth: 0)),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [AppColors.secondary.withValues(alpha: 0.2), AppColors.secondary.withValues(alpha: 0.0)],
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true, drawVerticalLine: false, horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 35, interval: 1,
              getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 72,
        maxY: 78,
        barGroups: _weightData.asMap().entries.map((e) {
          final isLatest = e.key == _weightData.length - 1;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: isLatest ? AppColors.primary : AppColors.primary.withValues(alpha: 0.4),
                width: 14,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
