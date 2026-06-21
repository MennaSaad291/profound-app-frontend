import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class ProfessorDashboard extends StatefulWidget {
  const ProfessorDashboard({super.key});

  @override
  State<ProfessorDashboard> createState() => _ProfessorDashboardState();
}

class _ProfessorDashboardState extends State<ProfessorDashboard> {
  static const String _base = 'http://127.0.0.1:8000';

  bool _isLoading = true;
  double classAverage = 0;
  double averageTrend = 0;
  int atRiskCount = 0;
  int pendingGrading = 0;
  int totalStudents = 0;
  int totalCourses = 0;

  int? _userId;
  String _professorName = "Professor";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _professorName = args?['name'] ?? "Professor";
    final rawId = args?['user_id'] ?? args?['id'];
    _userId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (_userId != null && _isLoading) _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (_userId == null) return;
    try {
      final res = await http
          .get(Uri.parse('$_base/dashboard-stats/$_userId'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          classAverage = (data['class_average'] as num?)?.toDouble() ?? 0;
          averageTrend = (data['average_trend'] as num?)?.toDouble() ?? 0;
          atRiskCount = (data['at_risk_count'] as num?)?.toInt() ?? 0;
          pendingGrading = (data['pending_grading'] as num?)?.toInt() ?? 0;
          totalStudents = (data['total_students'] as num?)?.toInt() ?? 0;
          totalCourses = (data['total_courses'] as num?)?.toInt() ?? 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _fetchStats();
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F3FF), Colors.white, Color(0xFFFFFBEB)],
          ),
        ),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Welcome back Professor, $_professorName",
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const Text("Here's your academic overview",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 8),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(
                          backgroundColor: Color(0xFFEDE9FE),
                          color: Color(0xFF9333EA),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ── Summary Row ──
                    Row(children: [
                      _buildMiniStat("$totalCourses", "Courses", Icons.menu_book, const Color(0xFF4F46E5)),
                      const SizedBox(width: 12),
                      _buildMiniStat("$totalStudents", "Students", Icons.people_outline, const Color(0xFF059669)),
                    ]),
                    const SizedBox(height: 20),

                    _buildSectionHeader("Current Workload"),
                    const SizedBox(height: 12),

                    _buildWorkloadCard(
                      label: "Current Class Average",
                      value: classAverage > 0 ? "${classAverage.toStringAsFixed(1)}%" : "—",
                      trend: averageTrend != 0
                          ? "${averageTrend > 0 ? '+' : ''}${averageTrend.toStringAsFixed(1)}%"
                          : null,
                      trendPositive: averageTrend >= 0,
                      icon: Icons.bar_chart,
                      color: classAverage >= 70
                          ? Colors.green
                          : classAverage >= 50
                              ? Colors.orange
                              : Colors.red,
                      bottomWidget: classAverage == 0 && !_isLoading
                          ? const Text("No graded submissions yet",
                              style: TextStyle(color: Colors.grey, fontSize: 12))
                          : null,
                    ),
                    const SizedBox(height: 12),

                    _buildWorkloadCard(
                      label: "At-Risk Students",
                      value: "$atRiskCount",
                      subtext: atRiskCount == 1 ? "Student Identified" : "Students Identified",
                      icon: Icons.error_outline,
                      color: atRiskCount == 0 ? Colors.green : Colors.amber,
                      buttonText: "View Predictive Analysis",
                      onButtonPressed: () => Navigator.pushNamed(context, '/analytics'),
                    ),
                    const SizedBox(height: 12),

                    _buildWorkloadCard(
                      label: "Pending Grading",
                      value: "$pendingGrading",
                      subtext: pendingGrading == 1 ? "Assignment Due" : "Assignments Due",
                      icon: Icons.assignment_turned_in_outlined,
                      color: pendingGrading == 0 ? Colors.green : Colors.blue,
                      linkText: "Go to Grading Module →",
                      onLinkPressed: () => Navigator.pushNamed(context, '/grading', arguments:_userId,),
                    ),

                    const SizedBox(height: 24),

                    _buildSectionHeader("Quick Actions"),
                    const SizedBox(height: 12),
                    _buildFeatureButton(
                      title: "AI Grading System",
                      subtitle: "Automated grading with NLP",
                      icon: Icons.check_circle_outline,
                      gradient: const [Color(0xFF9333EA), Color(0xFF7E22CE)],
                      onTap: () => Navigator.pushNamed(context, '/grading',arguments:_userId,),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureButton(
                      title: "Generate Lecture Materials",
                      subtitle: "AI-powered content creation",
                      icon: Icons.menu_book,
                      gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                      onTap: () => Navigator.pushNamed(context, '/generate_lecture'),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureButton(
                      title: "Exam Generation Tools",
                      subtitle: "Create assessments instantly",
                      icon: Icons.edit_note,
                      gradient: const [Color(0xFF4F46E5), Color(0xFF4338CA)],
                      onTap: () => Navigator.pushNamed(context, '/exam_generator'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54));
  }

  Widget _buildWorkloadCard({
    required String label,
    required String value,
    String? trend,
    bool trendPositive = true,
    String? subtext,
    required IconData icon,
    required Color color,
    String? buttonText,
    VoidCallback? onButtonPressed,
    String? linkText,
    VoidCallback? onLinkPressed,
    Widget? bottomWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(value,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      if (trend != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          trendPositive ? Icons.trending_up : Icons.trending_down,
                          color: trendPositive ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        Text(trend,
                            style: TextStyle(
                                color: trendPositive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold)),
                      ],
                      if (subtext != null) ...[
                        const SizedBox(width: 8),
                        Text(subtext,
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ]),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          if (bottomWidget != null) ...[
            const SizedBox(height: 8),
            bottomWidget,
          ],
          if (buttonText != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9333EA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(buttonText),
              ),
            ),
          ],
          if (linkText != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onLinkPressed,
              child: Text(linkText,
                  style: const TextStyle(
                      color: Color(0xFF9333EA),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: gradient[0].withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
