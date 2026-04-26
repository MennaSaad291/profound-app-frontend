import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfessorDashboard extends StatefulWidget {
  const ProfessorDashboard({super.key});

  @override
  State<ProfessorDashboard> createState() => _ProfessorDashboardState();
}

class _ProfessorDashboardState extends State<ProfessorDashboard> {

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String professorName = args?['name'] ?? "Professor"; 
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F3FF), Colors.white, Color(0xFFFFFBEB)],
        ),
      ),
      child: CustomScrollView(
        slivers: [      
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome back Professor, $professorName",
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const Text("Here's your academic overview", 
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 24),

                  _buildSectionHeader("Current Workload"),
                  const SizedBox(height: 12),
                  _buildWorkloadCard(
                    label: "Current Class Average",
                    value: "82.5%",
                    trend: "+2.3%",
                    icon: Icons.bar_chart,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildWorkloadCard(
                    label: "At-Risk Students",
                    value: "3",
                    subtext: "Students Identified",
                    icon: Icons.error_outline,
                    color: Colors.amber,
                    buttonText: "View Predictive Analysis",
                    onButtonPressed: () => Navigator.pushNamed(context, '/analytics'),
                  ),
                  const SizedBox(height: 12),
                  _buildWorkloadCard(
                    label: "Pending Grading",
                    value: "12",
                    subtext: "Assignments Due",
                    icon: Icons.assignment_turned_in_outlined,
                    color: Colors.blue,
                    linkText: "Go to Grading Module →",
                    onLinkPressed: () => Navigator.pushNamed(context, '/grading'),
                  ),
                  
                  const SizedBox(height: 24),

                  _buildSectionHeader("Quick Actions"),
                  const SizedBox(height: 12),
                  _buildFeatureButton(
                    title: "AI Grading System",
                    subtitle: "Automated grading with NLP",
                    icon: Icons.check_circle_outline,
                    gradient: const [Color(0xFF9333EA), Color(0xFF7E22CE)],
                    onTap: () => Navigator.pushNamed(context, '/grading'),
                  ),
                  const SizedBox(height: 12),
                  
                  // --- FIXED: Connected to the AI Lecture Screen ---
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
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54));
  }

  Widget _buildWorkloadCard({required String label, required String value, String? trend, String? subtext, required IconData icon, required Color color, String? buttonText, VoidCallback? onButtonPressed, String? linkText, VoidCallback? onLinkPressed}) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      if (trend != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.trending_up, color: Colors.green, size: 16),
                        Text(trend, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                      if (subtext != null) ...[
                        const SizedBox(width: 8),
                        Text(subtext, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ]
                    ],
                  )
                ],
              ),
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              )
            ],
          ),
          if (buttonText != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9333EA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(buttonText),
              ),
            )
          ],
          if (linkText != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onLinkPressed,
              child: Text(linkText, style: const TextStyle(color: Color(0xFF9333EA), fontWeight: FontWeight.w600)),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildFeatureButton({required String title, required String subtitle, required IconData icon, required List<Color> gradient, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}