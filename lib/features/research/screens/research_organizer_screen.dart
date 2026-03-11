import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class ResearchOrganizerScreen extends StatefulWidget {
  const ResearchOrganizerScreen({super.key});

  @override
  State<ResearchOrganizerScreen> createState() => _ResearchOrganizerScreenState();
}

class _ResearchOrganizerScreenState extends State<ResearchOrganizerScreen> {
  String _viewMode = 'board'; // 'board' or 'list'

  final List<Map<String, dynamic>> _projects = [
    {
      'id': 1,
      'title': 'AI-Powered Automated Grading Systems in Higher Education',
      'status': 'under-review',
      'deadline': '2025-12-15',
      'collaborators': ['Dr. Sarah Johnson', 'Dr. Michael Chen'],
      'progress': 75,
    },
    {
      'id': 2,
      'title': 'Natural Language Processing for Arabic Academic Texts',
      'status': 'drafting',
      'deadline': '2026-01-30',
      'collaborators': ['Dr. Omar Hassan', 'Dr. Layla Ibrahim'],
      'progress': 45,
    },
    {
      'id': 3,
      'title': 'Machine Learning Models for Student Performance Prediction',
      'status': 'submitted',
      'deadline': '2025-12-01',
      'collaborators': ['Dr. Emily Rodriguez'],
      'progress': 100,
    },
    {
      'id': 4,
      'title': 'Learning Analytics Dashboard for Educational Institutions',
      'status': 'drafting',
      'deadline': '2026-02-28',
      'collaborators': ['Dr. James Wilson', 'Dr. Maria Garcia'],
      'progress': 30,
    },
  ];

  final List<Map<String, dynamic>> _upcomingDeadlines = [
    {'title': 'ML Performance Paper - IEEE Submit', 'date': '2025-12-01', 'daysLeft': 5},
    {'title': 'AI Grading Review Response', 'date': '2025-12-15', 'daysLeft': 19},
    {'title': 'Arabic NLP Conference Abstract', 'date': '2026-01-30', 'daysLeft': 65},
  ];

  final List<Map<String, dynamic>> _literaturePapers = [
    {'title': 'Deep Learning Approaches in Educational Assessment', 'status': 'read', 'citation': 'APA'},
    {'title': 'Automated Essay Scoring: A Survey', 'status': 'reading', 'citation': 'IEEE'},
    {'title': 'NLP Techniques for Academic Text Analysis', 'status': 'to-read', 'citation': 'APA'},
    {'title': 'Machine Learning in Higher Education', 'status': 'read', 'citation': 'MLA'},
    {'title': 'Ethical Considerations in AI Grading', 'status': 'reading', 'citation': 'APA'},
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'drafting': return const Color(0xFF1D4ED8);
      case 'under-review': return const Color(0xFFB45309);
      case 'submitted': return const Color(0xFF7E22CE);
      case 'published': return const Color(0xFF15803D);
      default: return Colors.grey;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'drafting': return const Color(0xFFEFF6FF);
      case 'under-review': return const Color(0xFFFFFBEB);
      case 'submitted': return const Color(0xFFFAF5FF);
      case 'published': return const Color(0xFFF0FDF4);
      default: return Colors.grey[100]!;
    }
  }

  Color _getReadStatusColor(String status) {
    switch (status) {
      case 'to-read': return Colors.grey[700]!;
      case 'reading': return const Color(0xFF1D4ED8);
      case 'read': return const Color(0xFF15803D);
      default: return Colors.grey[700]!;
    }
  }

  Color _getReadStatusBgColor(String status) {
    switch (status) {
      case 'to-read': return Colors.grey[100]!;
      case 'reading': return const Color(0xFFEFF6FF);
      case 'read': return const Color(0xFFF0FDF4);
      default: return Colors.grey[100]!;
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
            colors: [Color(0xFFF3E5F5), Colors.white, Color(0xFFFFF8E1)],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildQuickStats(),
                    const SizedBox(height: 16),
                    _buildProjectsSection(),
                    const SizedBox(height: 16),
                    _buildLiteratureTracker(),
                    const SizedBox(height: 16),
                    _buildMiniCalendar(),
                    const SizedBox(height: 16),
                    _buildUpcomingDeadlines(),
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

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 80,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6B21A8), Color(0xFF9333EA), Color(0xFFD97706)],
            ),
          ),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Research Organizer',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Manage your academic projects',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Research Overview', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: [
              _statTile('4', 'Active Projects'),
              _statTile('2', 'In Progress'),
              _statTile('1', 'Under Review'),
              _statTile('3', 'To Read'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildProjectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('My Projects', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              children: [
                _viewToggleBtn('Board', 'board'),
                const SizedBox(width: 8),
                _viewToggleBtn('List', 'list'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._projects.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildProjectCard(p),
        )),
      ],
    );
  }

  Widget _viewToggleBtn(String label, String mode) {
    final isActive = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.primaryPurple : Colors.grey[300]!),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isActive ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w500,
            )),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final statusColor = _getStatusColor(project['status']);
    final statusBg = _getStatusBgColor(project['status']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(project['title'],
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, height: 1.4)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  project['status'].toString().replaceAll('-', ' '),
                  style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
              Text('${project['progress']}%',
                  style: GoogleFonts.inter(color: AppColors.primaryPurple, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: project['progress'] / 100,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 4),
              Text('Deadline: ${project['deadline']}',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700])),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.people_outline, size: 14, color: AppColors.primaryPurple),
              const SizedBox(width: 4),
              Text('Collaborators', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700])),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (project['collaborators'] as List<String>)
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(c, style: GoogleFonts.inter(color: AppColors.primaryPurple, fontSize: 10)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
              label: Text('View Details', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiteratureTracker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
        border: Border.all(color: Colors.grey[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFFAF5FF), Color(0xFFFFFBEB)]),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, color: AppColors.primaryPurple),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Literature Tracker',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Papers for current research',
                          style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: _literaturePapers.asMap().entries.map((entry) {
                final paper = entry.value;
                final isLast = entry.key == _literaturePapers.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(paper['title'],
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getReadStatusBgColor(paper['status']),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  paper['status'].toString().replaceAll('-', ' '),
                                  style: GoogleFonts.inter(
                                      color: _getReadStatusColor(paper['status']), fontSize: 11),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(paper['citation'],
                                    style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) Divider(color: Colors.grey[100], height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: AppColors.primaryPurple),
              const SizedBox(width: 8),
              Text('December 2025',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            children: [
              ...['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => Center(
                    child: Text(d, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                  )),
              ...List.generate(31, (i) {
                final day = i + 1;
                final isDeadline = day == 1 || day == 15;
                final isToday = day == 2;
                Color bg = Colors.transparent;
                Color textColor = Colors.grey[700]!;
                if (isToday) { bg = AppColors.primaryPurple; textColor = Colors.white; }
                else if (isDeadline) { bg = const Color(0xFFFEE2E2); textColor = const Color(0xFFB91C1C); }
                return GestureDetector(
                  onTap: () {},
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                    child: Center(
                      child: Text('$day',
                          style: GoogleFonts.inter(fontSize: 11, color: textColor)),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _legendItem(const Color(0xFFFEE2E2), 'Deadline'),
                const SizedBox(height: 4),
                _legendItem(AppColors.primaryPurple, 'Today'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildUpcomingDeadlines() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Text('Upcoming Deadlines',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ..._upcomingDeadlines.map((d) {
            Color borderColor;
            Color bgColor;
            Color textColor;
            if (d['daysLeft'] <= 7) {
              borderColor = const Color(0xFFFCA5A5);
              bgColor = const Color(0xFFFEF2F2);
              textColor = const Color(0xFFB91C1C);
            } else if (d['daysLeft'] <= 30) {
              borderColor = const Color(0xFFFCD34D);
              bgColor = const Color(0xFFFFFBEB);
              textColor = const Color(0xFFB45309);
            } else {
              borderColor = const Color(0xFF93C5FD);
              bgColor = const Color(0xFFEFF6FF);
              textColor = const Color(0xFF1D4ED8);
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['title'],
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(d['date'],
                            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                      ],
                    ),
                  ),
                  Text('${d['daysLeft']} days left',
                      style: GoogleFonts.inter(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
