import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';

class FullAnalyticsReportsModule extends StatefulWidget {
  final VoidCallback onBack;
  final String? preSelectedCourse;
  const FullAnalyticsReportsModule({
    super.key,
    required this.onBack,
    this.preSelectedCourse,
  });
  @override
  State<FullAnalyticsReportsModule> createState() =>
      _FullAnalyticsReportsModuleState();
}

class _FullAnalyticsReportsModuleState
    extends State<FullAnalyticsReportsModule> {
  String selectedCourse = 'All Courses';
  String selectedSemester = 'Fall 2025';
  String dateRange = 'Current Semester';
  bool showFilters = false;
  int _touchedIndex = -1;
  bool showReportConfig = false;

  final List<Map<String, dynamic>> performanceDistribution = [
    {
      'name': 'Excellent (90-100)',
      'value': 23.0,
      'color': const Color(0xFF10B981),
    },
    {'name': 'Good (80-89)', 'value': 35.0, 'color': const Color(0xFF3B82F6)},
    {
      'name': 'Average (70-79)',
      'value': 27.0,
      'color': const Color(0xFFF59E0B),
    },
    {'name': 'At-Risk (<70)', 'value': 15.0, 'color': const Color(0xFFEF4444)},
  ];
  final List<Map<String, dynamic>> departmentBenchmarks = [
    {
      'metric': 'Average Grade',
      'yourCourse': 78.5,
      'department': 76.2,
      'difference': '+2.3',
    },
    {
      'metric': 'Pass Rate',
      'yourCourse': 88.0,
      'department': 85.0,
      'difference': '+3%',
    },
    {
      'metric': 'Attendance Rate',
      'yourCourse': 84.0,
      'department': 82.0,
      'difference': '+2%',
    },
    {
      'metric': 'Assignment Completion',
      'yourCourse': 86.0,
      'department': 80.0,
      'difference': '+6%',
    },
  ];
  final List<Map<String, dynamic>> errorAnalysisData = [
    {
      'category': 'Logic Errors',
      'count': 156,
      'percentage': 35,
      'topErrors': [
        {'error': 'Incorrect loop conditions', 'count': 45, 'students': 28},
        {'error': 'Off-by-one errors', 'count': 38, 'students': 24},
        {'error': 'Incorrect conditionals', 'count': 32, 'students': 20},
      ],
    },
    {
      'category': 'Syntax Errors',
      'count': 98,
      'percentage': 22,
      'topErrors': [
        {'error': 'Missing semicolons', 'count': 28, 'students': 18},
        {'error': 'Bracket mismatch', 'count': 25, 'students': 16},
        {'error': 'Variable declaration errors', 'count': 24, 'students': 15},
      ],
    },
    {
      'category': 'Conceptual Errors',
      'count': 125,
      'percentage': 28,
      'topErrors': [
        {
          'error': 'Misunderstanding of OOP principles',
          'count': 38,
          'students': 22,
        },
        {
          'error': 'Incorrect data structure usage',
          'count': 35,
          'students': 20,
        },
        {'error': 'Algorithm complexity issues', 'count': 30, 'students': 18},
      ],
    },
    {
      'category': 'Documentation Errors',
      'count': 67,
      'percentage': 15,
      'topErrors': [
        {'error': 'Missing function comments', 'count': 22, 'students': 15},
        {'error': 'Incomplete documentation', 'count': 18, 'students': 12},
        {'error': 'Incorrect comment format', 'count': 15, 'students': 10},
      ],
    },
  ];
  Map<String, bool> reportConfig = {
    'includeStudentPII': false,
    'includeDepartmentBenchmarks': true,
    'includeErrorAnalysis': true,
    'includePredictiveMetrics': true,
    'includeAttendanceData': true,
    'includeGradeDistribution': true,
  };
  final List<Map<String, String>> reportOptions = [
    {
      'key': 'includeStudentPII',
      'title': 'Include Student PII',
      'subtitle': 'Names, IDs, and contact information',
    },
    {
      'key': 'includeDepartmentBenchmarks',
      'title': 'Department Benchmarks',
      'subtitle': 'Comparative analytics',
    },
    {
      'key': 'includeErrorAnalysis',
      'title': 'Error Analysis Detail',
      'subtitle': 'Common mistakes and patterns',
    },
    {
      'key': 'includePredictiveMetrics',
      'title': 'Predictive Analytics',
      'subtitle': 'AI-powered performance forecasts',
    },
    {
      'key': 'includeAttendanceData',
      'title': 'Attendance Data',
      'subtitle': 'Detailed attendance records',
    },
    {
      'key': 'includeGradeDistribution',
      'title': 'Grade Distribution Charts',
      'subtitle': 'Visual performance breakdowns',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedCourse != null) {
      selectedCourse = widget.preSelectedCourse!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E8FF), Colors.white, Color(0xFFFFFBEB)],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUploadSection(),
                    _buildFilterSection(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        "Advanced Analytics & Insights",
                        style: TextStyle(fontSize: 18, color: Colors.black87),
                      ),
                    ),
                    _buildPredictiveChart(),
                    _buildCorrelationChart(),
                    _buildPieChartSection(),
                    _buildErrorAnalysisSection(),
                    _buildBenchmarksSection(),
                    _buildReportConfigSection(),
                    _buildExportButton(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarksSection() {
    return _buildCard(
      title: "Department Benchmarks",
      subtitle: "Compare your course performance against department averages",
      icon: LucideIcons.barChart3,
      child: Column(
        children: departmentBenchmarks.map((benchmark) {
          bool isPositive = benchmark['difference'].toString().startsWith('+');
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(benchmark['metric'], style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildBenchmarkBox(
                      "${benchmark['yourCourse']}%",
                      "Your Course",
                      const Color(0xFFF5F3FF),
                      const Color(0xFF7E22CE),
                    ),
                    const SizedBox(width: 6),
                    _buildBenchmarkBox(
                      "${benchmark['department']}%",
                      "Department",
                      const Color(0xFFF9FAFB),
                      const Color(0xFF374151),
                    ),
                    const SizedBox(width: 6),
                    _buildBenchmarkBox(
                      benchmark['difference'],
                      "Difference",
                      isPositive
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFEF2F2),
                      isPositive
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB91C1C),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBenchmarkBox(
    String value,
    String label,
    Color bg,
    Color textColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: textColor, fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 4,
      automaticallyImplyLeading: true,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7E22CE), Color(0xFFD97706)],
          ),
        ),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Profound Data & Reporting",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          Text(
            "UCD-7 • US-8",
            style: TextStyle(color: Color(0xFFE9D5FF), fontSize: 11),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: widget.onBack,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.jpeg',
                  fit: BoxFit.cover,
                  width: 36,
                  height: 36,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9333EA), Color(0xFF7E22CE)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.upload, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                "Intelligent Data Upload",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Upload existing grade sheets or attendance records for advanced analysis",
            style: TextStyle(color: Color(0xFFF3E8FF), fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF7E22CE),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {},
            icon: const Icon(LucideIcons.fileSpreadsheet, size: 18),
            label: const Text("Upload Excel/CSV File"),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => showFilters = !showFilters),
            leading: const Icon(LucideIcons.filter, color: Color(0xFF9333EA)),
            title: const Text("Data Filters & Scope"),
            trailing: Icon(
              showFilters ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            ),
          ),
          if (showFilters)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDropdown(
                    "Course",
                    selectedCourse,
                    [
                      'All Courses',
                      'IS 405 - Information Systems Analysis',
                      'CS 401 - Artificial Intelligence',
                      'CS 301 - Software Design',
                      'CS 201 - Data Structures',
                    ],
                    (val) => setState(() => selectedCourse = val!),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    "Semester",
                    selectedSemester,
                    ['Fall 2025', 'Spring 2025', 'Fall 2024', 'All Semesters'],
                    (val) => setState(() => selectedSemester = val!),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown("Date Range", dateRange, [
                    'Current Semester',
                    'Last 30 Days',
                    'Last Quarter',
                    'Academic Year',
                  ], (val) => setState(() => dateRange = val!)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => showFilters = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9333EA),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Apply Filters"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPredictiveChart() {
    return _buildCard(
      title: "Predictive Performance Model",
      subtitle: "Machine learning predictions based on performance trends",
      icon: LucideIcons.activity,
      badge: "AI-Powered",
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 70,
                maxY: 85,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.white,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final isActual = barSpot.barIndex == 0;
                        return LineTooltipItem(
                          '${isActual ? "Actual" : "Predicted"}: ${barSpot.y.toInt()}',
                          TextStyle(
                            color: isActual
                                ? const Color(0xFF9333EA)
                                : const Color(0xFFF59E0B),

                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: Color(0xFFF0F0F0), strokeWidth: 1),
                  getDrawingVerticalLine: (value) =>
                      const FlLine(color: Color(0xFFF0F0F0), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 5,
                      getTitlesWidget: (val, _) => Text(
                        val.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (val, _) {
                        const weeks = [
                          'W1',
                          'W2',
                          'W3',
                          'W4',
                          'W5',
                          'W6',
                          'Cur',
                          'W8',
                        ];
                        int index = val.toInt();
                        if (index >= 0 && index < weeks.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              weeks[index],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          );
                        }
                        return const Text("");
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 74),
                      FlSpot(1, 77),
                      FlSpot(2, 75),
                      FlSpot(3, 79),
                      FlSpot(4, 78),
                      FlSpot(5, 80),
                    ],
                    isCurved: true,
                    color: const Color(0xFF9333EA),
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF9333EA).withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 75),
                      FlSpot(1, 76),
                      FlSpot(2, 77),
                      FlSpot(3, 78),
                      FlSpot(4, 80),
                      FlSpot(5, 81),
                      FlSpot(6, 82),
                      FlSpot(7, 83),
                    ],
                    isCurved: true,
                    color: const Color(0xFFF59E0B),
                    barWidth: 2,
                    dashArray: [5, 5],
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem("Actual Performance", const Color(0xFF9333EA)),
              const SizedBox(width: 20),
              _buildLegendItem(
                "Predicted Performance",
                const Color(0xFFF59E0B),
                isDashed: true,
              ),
            ],
          ),
        ],
      ),
      footer: _buildInsightBox(
        "Prediction Insight",
        "Based on current trends, class average expected to reach 82% by week 8. Recommend intervention for 8 at-risk students to improve trajectory.",
      ),
    );
  }

  Widget _buildCorrelationChart() {
    return _buildCard(
      title: "Attendance-Grade Correlation",
      subtitle:
          "Strong correlation (R² = 0.89) between attendance and final performance",
      icon: LucideIcons.target,
      child: Column(
        children: [
          SizedBox(
            height: 250,
            child: ScatterChart(
              ScatterChartData(
                minX: 0,
                maxX: 100,
                minY: 0,
                maxY: 100,

                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: const Color(0xFFF0F0F0), strokeWidth: 1),
                  getDrawingVerticalLine: (value) =>
                      FlLine(color: const Color(0xFFF0F0F0), strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFD1D5DB)),
                    left: BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      "Attendance %",
                      style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 25,
                      getTitlesWidget: (val, _) => Text(
                        "${val.toInt()}",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      "Grade %",
                      style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 25,
                      getTitlesWidget: (val, _) => Text(
                        "${val.toInt()}",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ),

                scatterTouchData: ScatterTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: ScatterTouchTooltipData(
                    tooltipBgColor: Colors.white,
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(12),
                    tooltipBorder: const BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1,
                    ),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (ScatterSpot touchedSpot) {
                      return ScatterTooltipItem(
                        'Attendance % : ${touchedSpot.x.toInt()}\nFinal Grade : ${touchedSpot.y.toInt()}',
                        textStyle: const TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      );
                    },
                  ),
                ),
                scatterSpots:
                    [
                          ScatterSpot(50, 48),
                          ScatterSpot(55, 52),
                          ScatterSpot(60, 58),
                          ScatterSpot(65, 62),
                          ScatterSpot(70, 68),
                          ScatterSpot(72, 74),
                          ScatterSpot(78, 76),
                          ScatterSpot(82, 84),
                          ScatterSpot(85, 88),
                          ScatterSpot(88, 90),
                          ScatterSpot(92, 92),
                          ScatterSpot(95, 95),
                          ScatterSpot(98, 98),
                        ]
                        .map(
                          (spot) => ScatterSpot(
                            spot.x,
                            spot.y,
                            dotPainter: FlDotCirclePainter(
                              color: const Color(0xFF9333EA).withOpacity(0.7),
                              radius: 4.5,
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCorrelationInsight(
                  "Correlation",
                  "R² = 0.89 (Strong)",
                  const Color(0xFFF5F3FF),
                  const Color(0xFF7E22CE),
                  const Color(0xFFDDD6FE),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCorrelationInsight(
                  "Insight",
                  "Each 10% attendance ↑ = 8% grade ↑",
                  const Color(0xFFFFFBEB),
                  const Color(0xFFB45309),
                  const Color(0xFFFEF3C7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationInsight(
    String title,
    String desc,
    Color bg,
    Color textColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(desc, style: TextStyle(color: textColor, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildPieChartSection() {
    return _buildCard(
      title: "Performance Distribution",
      icon: LucideIcons.pieChart,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 320,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 0,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse
                              .touchedSection!
                              .touchedSectionIndex;
                        });
                      },
                    ),
                    sections: performanceDistribution.asMap().entries.map((
                      entry,
                    ) {
                      final int index = entry.key;
                      final data = entry.value;
                      final bool isTouched = index == _touchedIndex;
                      final double radius = isTouched ? 125.0 : 115.0;

                      return PieChartSectionData(
                        color: data['color'],
                        value: data['value'],
                        title: '${data['value'].toInt()}%',
                        radius: radius,
                        titlePositionPercentageOffset: 1.3,
                        titleStyle: TextStyle(
                          fontSize: isTouched ? 18 : 14,

                          color: const Color(0xFF374151),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (_touchedIndex != -1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    "${performanceDistribution[_touchedIndex]['name']}: ${performanceDistribution[_touchedIndex]['value'].toInt()}%",
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Wrap(
                  runSpacing: 8,
                  spacing: 20,
                  alignment: WrapAlignment.center,
                  children: performanceDistribution.asMap().entries.map((
                    entry,
                  ) {
                    final index = entry.key;
                    final item = entry.value;
                    final bool isTouched = index == _touchedIndex;

                    return SizedBox(
                      width: 150,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: item['color'],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${item['name']}: ${item['value'].toInt()}%",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isTouched
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isTouched
                                    ? Colors.black
                                    : const Color(0xFF4B5563),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorAnalysisSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFEF2F2), Color(0xFFFFFBEB)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      LucideIcons.alertCircle,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Common Error Analysis",
                      style: TextStyle(fontSize: 15, color: Color(0xFF111827)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "Granular error patterns across all assignments",
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 12),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...errorAnalysisData
                    .map((category) => _buildErrorCategoryCard(category))
                    .toList(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF2F2),
                      foregroundColor: const Color(0xFFB91C1C),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "View Detailed Error Report →",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCategoryCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['category'],
                style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
              ),
              Row(
                children: [
                  Text(
                    "${data['count']} errors",
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${data['percentage']}%",
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),

                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...((data['topErrors'] as List)
              .map(
                (error) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              error['error'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Affected: ${error['students']} students",
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "${error['count']}x",
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList()),
        ],
      ),
    );
  }

  Widget _buildReportConfigSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
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
          InkWell(
            onTap: () => setState(() => showReportConfig = !showReportConfig),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFBEB), Color(0xFFFAF5FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: showReportConfig
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.fileText,
                        color: Color(0xFFD97706),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Report Configuration",
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: showReportConfig ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      LucideIcons.chevronDown,
                      color: Color(0xFF4B5563),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showReportConfig)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Customize what to include in your exported report",
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ...reportOptions.map((option) {
                    final String key = option['key']!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () => setState(
                          () => reportConfig[key] = !reportConfig[key]!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB), // bg-gray-50
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: Checkbox(
                                  value: reportConfig[key],
                                  activeColor: const Color(0xFF9333EA),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) =>
                                      setState(() => reportConfig[key] = val!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option['title']!,
                                      style: const TextStyle(
                                        color: Color(0xFF111827),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    Text(
                                      option['subtitle']!,
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: const Icon(LucideIcons.download),
      label: const Text("Generate & Export Formal Report (PDF)"),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool isDashed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: isDashed ? 2 : 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    String? subtitle,
    required IconData icon,
    String? badge,
    required Widget child,
    Widget? footer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF9333EA), size: 20),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 15)),
                ],
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFF9333EA),
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          child,
          if (footer != null) ...[const SizedBox(height: 12), footer],
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildInsightBox(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.zap, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$title: $body",
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
