import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CourseDetailsDashboard extends StatefulWidget {
  const CourseDetailsDashboard({super.key});

  @override
  State<CourseDetailsDashboard> createState() => _CourseDetailsDashboardState();
}

class _CourseDetailsDashboardState extends State<CourseDetailsDashboard> {
  Map<String, dynamic>? analytics;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('id') && analytics == null) {
      _fetchAnalytics(args['id']);
    }
  }

  Future<void> _fetchAnalytics(int courseId) async {
    final url = Uri.parse('http://localhost:8000/course-analytics/$courseId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          analytics = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? 
                 {'code': 'CS 401', 'name': 'Artificial Intelligence'};

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildIdentityHeader(args),
          const SizedBox(height: 20),
          _buildPerformanceOverview(),
          const SizedBox(height: 20),
          _buildTrendCard(),
          const SizedBox(height: 20),
          _buildGradeDistribution(), 
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildIdentityHeader(Map<String, dynamic> args) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF9333EA), Color(0xFFD97706)]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(args['name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text("${args['semester'] ?? 'Fall 2025'} • Room 201", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPerformanceOverview() {
    return Row(
      children: [
        _miniMetricCard("Average", analytics?['average'] ?? "78.5%", Colors.purple, Icons.analytics),
        const SizedBox(width: 12),
        _miniMetricCard("At Risk", "${analytics?['at_risk'] ?? 8}", Colors.red, Icons.warning_amber),
      ],
    );
  }

  Widget _miniMetricCard(String label, String val, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.1))),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard() {
    final List<dynamic> trend = analytics?['trend'] ?? [70, 75, 72, 80, 78];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Performance Trend", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.7, 
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Colors.grey, fontSize: 10);
                        switch (value.toInt()) {
                          case 0: return const Text('W1', style: style);
                          case 2: return const Text('W3', style: style);
                          case 4: return const Text('W5', style: style);
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(color: Colors.grey[400]!, width: 1),
                    bottom: BorderSide(color: Colors.grey[400]!, width: 1),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                    isCurved: true,
                    color: Colors.purple,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: Colors.purple.withOpacity(0.1)),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDistribution() {
    final Map<String, dynamic> dist = analytics?['distribution'] ?? {"A": 12, "B": 18, "C": 14, "D": 5, "F": 3};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Grade Distribution", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 2,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 25,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Colors.grey, fontSize: 10);
                        switch (value.toInt()) {
                          case 0: return const Text('A', style: style);
                          case 1: return const Text('B', style: style);
                          case 2: return const Text('C', style: style);
                          case 3: return const Text('D', style: style);
                          case 4: return const Text('F', style: style);
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100]!, strokeWidth: 1)),
                borderData: FlBorderData(show: true, border: Border(left: BorderSide(color: Colors.grey[400]!, width: 1), bottom: BorderSide(color: Colors.grey[400]!, width: 1))),
                barGroups: [
                  _makeGroupData(0, dist['A'].toDouble(), Colors.green),
                  _makeGroupData(1, dist['B'].toDouble(), Colors.blue),
                  _makeGroupData(2, dist['C'].toDouble(), Colors.amber),
                  _makeGroupData(3, dist['D'].toDouble(), Colors.orange),
                  _makeGroupData(4, dist['F'].toDouble(), Colors.red),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildLegend(),
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          backDrawRodData: BackgroundBarChartRodData(show: true, toY: 25, color: Colors.grey[50]),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16, runSpacing: 8,
      children: [
        _legendItem("A (Excellent)", Colors.green),
        _legendItem("B (Good)", Colors.blue),
        _legendItem("C (Average)", Colors.amber),
        _legendItem("D (Poor)", Colors.orange),
        _legendItem("F (Fail)", Colors.red),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}