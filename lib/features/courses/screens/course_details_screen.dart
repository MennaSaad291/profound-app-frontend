import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:profound_app_frontend/core/constants/api_constants.dart';

const String _base = ApiConstants.baseUrl;

class CourseDetailsDashboard extends StatefulWidget {
  const CourseDetailsDashboard({super.key});

  @override
  State<CourseDetailsDashboard> createState() => _CourseDetailsDashboardState();
}

class _CourseDetailsDashboardState extends State<CourseDetailsDashboard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? analytics;
  List<dynamic> scheduleSlots = [];
  bool _isLoading = true;
  late TabController _tabController;
  Map<String, dynamic>? _courseArgs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && analytics == null) {
      _courseArgs = args;
      _fetchAll(args['id']);
    }
  }

  Future<void> _fetchAll(int courseId) async {
    try {
      final res = await http.get(Uri.parse('$_base/course-analytics/$courseId'));
      if (!mounted) return;
      setState(() {
        if (res.statusCode == 200) analytics = jsonDecode(res.body);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSchedule() async {
    final courseId = _courseArgs?['id'];
    if (courseId == null) return;
    final res = await http.get(Uri.parse('$_base/courses/$courseId/schedule'));
    if (res.statusCode == 200 && mounted) {
      setState(() => scheduleSlots = jsonDecode(res.body));
    }
  }

  void _showSlotSheet({Map<String, dynamic>? existing}) {
    final courseId = _courseArgs?['id'];
    if (courseId == null) return;

    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    String selectedDay = existing?['day'] ?? days[0];
    final startCon = TextEditingController(text: existing?['start_time'] ?? '09:00');
    final endCon = TextEditingController(text: existing?['end_time'] ?? '10:30');
    final roomCon = TextEditingController(text: existing?['room'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF9333EA), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.schedule, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(existing == null ? "Add Lecture Slot" : "Edit Lecture Slot",
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),
              Text("Day", style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedDay,
                    isExpanded: true,
                    items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setSheet(() => selectedDay = v!),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _timeField("Start Time", startCon, ctx)),
                const SizedBox(width: 12),
                Expanded(child: _timeField("End Time", endCon, ctx)),
              ]),
              const SizedBox(height: 14),
              Text("Room / Location", style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: roomCon,
                decoration: InputDecoration(
                  hintText: "e.g. Building A, Room 201",
                  filled: true, fillColor: const Color(0xFFF8F9FE),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9333EA),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final body = jsonEncode({
                      "day": selectedDay,
                      "start_time": startCon.text.trim(),
                      "end_time": endCon.text.trim(),
                      "room": roomCon.text.trim(),
                    });
                    http.Response res;
                    if (existing == null) {
                      res = await http.post(
                        Uri.parse('$_base/courses/$courseId/schedule'),
                        headers: {"Content-Type": "application/json"},
                        body: body,
                      );
                    } else {
                      res = await http.put(
                        Uri.parse('$_base/courses/$courseId/schedule/${existing['id']}'),
                        headers: {"Content-Type": "application/json"},
                        body: body,
                      );
                    }
                    if (res.statusCode == 200 && ctx.mounted) {
                      Navigator.pop(ctx);
                      _refreshSchedule();
                    }
                  },
                  child: Text(existing == null ? "Add Slot" : "Save Changes",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeField(String label, TextEditingController con, BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final parts = con.text.split(':');
            final initial = TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 9,
              minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
            );
            final picked = await showTimePicker(context: ctx, initialTime: initial);
            if (picked != null) {
              con.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.access_time, size: 16, color: Color(0xFF9333EA)),
              const SizedBox(width: 8),
              Text(con.text, style: const TextStyle(fontSize: 15)),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteSlot(int slotId) async {
    final courseId = _courseArgs?['id'];
    if (courseId == null) return;
    await http.delete(Uri.parse('$_base/courses/$courseId/schedule/$slotId'));
    _refreshSchedule();
  }

  @override
  Widget build(BuildContext context) {
    final args = _courseArgs ?? (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {});

    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF9333EA)));

    return Column(
      children: [
        _buildIdentityHeader(args),
        Expanded(
          child: _buildAnalyticsTab(),
        ),
      ],
    );
  }

  Widget _buildIdentityHeader(Map<String, dynamic> args) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF9333EA), Color(0xFFD97706)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(args['name'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("${args['code'] ?? ''} • ${args['semester'] ?? ''}",
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.people_outline, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text("${args['students'] ?? 0} students enrolled",
                style: const TextStyle(color: Colors.white70, fontSize: 12)),

          ]),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _buildPerformanceOverview(),
        const SizedBox(height: 16),
        _buildTrendCard(),
        const SizedBox(height: 16),
        _buildGradeDistribution(),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildScheduleTab() {
    final dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final sorted = [...scheduleSlots]..sort((a, b) {
        final da = dayOrder.indexOf(a['day']);
        final db_ = dayOrder.indexOf(b['day']);
        if (da != db_) return da.compareTo(db_);
        return (a['start_time'] as String).compareTo(b['start_time'] as String);
      });

    return Column(
      children: [
        Expanded(
          child: sorted.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.calendar_today_outlined, size: 52, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text("No schedule yet", style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text("Tap + to add lecture slots", style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  itemBuilder: (ctx, i) => _buildSlotCard(sorted[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showSlotSheet(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Add Lecture Slot", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9333EA),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotCard(Map<String, dynamic> slot) {
    final dayColors = {
      'Monday': const Color(0xFF4F46E5),
      'Tuesday': const Color(0xFF0891B2),
      'Wednesday': const Color(0xFF059669),
      'Thursday': const Color(0xFFD97706),
      'Friday': const Color(0xFFDC2626),
      'Saturday': const Color(0xFF7C3AED),
      'Sunday': const Color(0xFF9333EA),
    };
    final color = dayColors[slot['day']] ?? const Color(0xFF9333EA);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(slot['day'].toString().substring(0, 3).toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.access_time, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text("${slot['start_time']} – ${slot['end_time']}",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1F2937))),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(child: Text(slot['room'] ?? 'TBA',
                      style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: color),
                onPressed: () => _showSlotSheet(existing: slot),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Delete Slot?"),
                    content: Text("Remove ${slot['day']} ${slot['start_time']}–${slot['end_time']}?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                      TextButton(
                        onPressed: () { Navigator.pop(context); _deleteSlot(slot['id']); },
                        child: const Text("Delete", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Analytics widgets (unchanged logic, same as before) ─────────────────

  Widget _buildPerformanceOverview() {
    return Row(children: [
      _miniMetricCard("Average", analytics?['average'] ?? "N/A", Colors.purple, Icons.analytics),
      const SizedBox(width: 12),
      _miniMetricCard("At Risk", "${analytics?['at_risk'] ?? 0}", Colors.red, Icons.warning_amber),
    ]);
  }

  Widget _miniMetricCard(String label, String val, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.1))),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Performance Trend", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        SizedBox(
          height: 180,
          child: LineChart(LineChartData(
            clipData: FlClipData.all(),
            minY: 0,
            maxY: 100,
            gridData: FlGridData(show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[200], strokeWidth: 1)),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 20,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= trend.length) return const Text('');
                    // only label every other point to avoid crowding
                    if (idx % 2 != 0) return const Text('');
                    return Text('W${idx + 1}',
                        style: const TextStyle(color: Colors.grey, fontSize: 10));
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: true,
                border: Border(
                    left: BorderSide(color: Colors.grey[400]!, width: 1),
                    bottom: BorderSide(color: Colors.grey[400]!, width: 1))),
            lineBarsData: [
              LineChartBarData(
                spots: trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value as num).toDouble())).toList(),
                isCurved: true, color: Colors.purple, barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: true, color: Colors.purple.withOpacity(0.1)),
              ),
            ],
          )),
        ),
      ]),
    );
  }

  Widget _buildGradeDistribution() {
    final Map<String, dynamic> dist = analytics?['distribution'] ?? {"A": 0, "B": 0, "C": 0, "D": 0, "F": 0};
    // safely parse each grade count to double
    double gradeVal(String key) {
      final v = dist[key];
      if (v == null) return 0;
      return (v as num).toDouble();
    }

    final double maxY = [
      gradeVal('A'), gradeVal('B'), gradeVal('C'), gradeVal('D'), gradeVal('F'),
    ].fold(0.0, (prev, e) => e > prev ? e : prev);
    final double chartMaxY = (maxY < 5 ? 5 : maxY + 5).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Grade Distribution", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: chartMaxY,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                  getTitlesWidget: (v, _) {
                    const s = TextStyle(color: Colors.grey, fontSize: 10);
                    switch (v.toInt()) {
                      case 0: return const Text('A', style: s);
                      case 1: return const Text('B', style: s);
                      case 2: return const Text('C', style: s);
                      case 3: return const Text('D', style: s);
                      case 4: return const Text('F', style: s);
                    }
                    return const Text('');
                  })),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                  getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[100]!, strokeWidth: 1)),
            borderData: FlBorderData(show: true,
                border: Border(left: BorderSide(color: Colors.grey[400]!, width: 1),
                    bottom: BorderSide(color: Colors.grey[400]!, width: 1))),
            barGroups: [
              _bar(0, gradeVal('A'), Colors.green),
              _bar(1, gradeVal('B'), Colors.blue),
              _bar(2, gradeVal('C'), Colors.amber),
              _bar(3, gradeVal('D'), Colors.orange),
              _bar(4, gradeVal('F'), Colors.red),
            ],
          )),
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _legendItem("A (Excellent)", Colors.green),
          _legendItem("B (Good)", Colors.blue),
          _legendItem("C (Average)", Colors.amber),
          _legendItem("D (Poor)", Colors.orange),
          _legendItem("F (Fail)", Colors.red),
        ]),
      ]),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) => BarChartGroupData(x: x, barRods: [
    BarChartRodData(toY: y, color: color, width: 16,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
  ]);

  Widget _legendItem(String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);
}
