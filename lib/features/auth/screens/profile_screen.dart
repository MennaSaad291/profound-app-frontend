import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_colors.dart';

class ProfessorProfileScreen extends StatefulWidget {
  const ProfessorProfileScreen({super.key});

  @override
  State<ProfessorProfileScreen> createState() => _ProfessorProfileScreenState();
}

class _ProfessorProfileScreenState extends State<ProfessorProfileScreen> {
  Map<String, dynamic>? profileData;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = ModalRoute.of(context)?.settings.arguments as int?;
    if (userId != null) {
      _fetchProfile(userId);
    }
  }

  Future<void> _fetchProfile(int userId) async {
    // If using Android Emulator, change 'localhost' to '10.0.2.2'
    final url = Uri.parse('http://localhost:8000/profile/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          profileData = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitData(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('http://localhost:8000$path');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      if (!mounted) return;
      Navigator.pop(context);
      _fetchProfile(profileData!['id']);
    }
  }

  void _showAddCourseSheet() {
    final codeCon = TextEditingController();
    final nameCon = TextEditingController();
    final semCon = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Add New Course", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: codeCon, decoration: const InputDecoration(labelText: "Course Code")),
            TextField(controller: nameCon, decoration: const InputDecoration(labelText: "Course Name")),
            TextField(controller: semCon, decoration: const InputDecoration(labelText: "Semester")),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => _submitData('/courses', {
                "user_id": profileData!['id'],
                "code": codeCon.text,
                "name": nameCon.text,
                "semester": semCon.text,
                "students": 0,
                "status": "active",
              }),
              child: const Text("Save Course", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAddPubSheet() {
    final tCon = TextEditingController();
    final jCon = TextEditingController();
    final yCon = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Add Publication", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: tCon, decoration: const InputDecoration(labelText: "Title")),
            TextField(controller: jCon, decoration: const InputDecoration(labelText: "Journal")),
            TextField(controller: yCon, decoration: const InputDecoration(labelText: "Year"), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => _submitData('/publications', {
                "user_id": profileData!['id'],
                "title": tCon.text,
                "journal": jCon.text,
                "year": int.tryParse(yCon.text) ?? 2024,
                "citations": 0,
              }),
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 16),
                    _buildEngagementMetrics(),
                    const SizedBox(height: 16),
                    _buildCollapsibleSection(
                      icon: Icons.book_outlined,
                      title: "Research & Publications",
                      items: profileData!['publications'] ?? [],
                      onAdd: _showAddPubSheet,
                      tag: 'pubs',
                    ),
                    const SizedBox(height: 12),
                    _buildCollapsibleSection(
                      icon: Icons.school_outlined,
                      title: "Courses Taught",
                      items: profileData!['courses'] ?? [],
                      onAdd: _showAddCourseSheet,
                      tag: 'courses',
                    ),
                    const SizedBox(height: 12),
                    _buildResearchInterests(),
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
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Academic Profile", style: TextStyle(color: Colors.white, fontSize: 16)),
            Text(profileData!['full_name'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7E22CE), Color(0xFF9333EA), Color(0xFFD97706)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF9333EA), Color(0xFF7E22CE)]),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profileData!['full_name'] ?? "", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.school, size: 16, color: Color(0xFF7E22CE)),
                        const SizedBox(width: 4),
                        Text("University Professor", style: TextStyle(color: Colors.purple[700], fontSize: 13)),
                      ],
                    ),
                    Text(profileData!['department'] ?? "", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: () {},
                icon: const Icon(Icons.edit, size: 18),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF9333EA)),
              )
            ],
          ),

          // --- TEMPORARY NAVIGATION BUTTON ---
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/courses'),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text("Manage My Courses"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9333EA),
                side: const BorderSide(color: Color(0xFF9333EA)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFAF5FF), Color(0xFFFFFBEB)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.description, size: 16, color: Color(0xFF9333EA)),
                    SizedBox(width: 6),
                    Text("About Me", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(profileData!['bio'] ?? "", style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEngagementMetrics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: Color(0xFF9333EA), size: 20),
              SizedBox(width: 8),
              Text("Engagement Metrics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _metricTile("Citations", "227", const Color(0xFFF0FDF4), const Color(0xFF15803D), Icons.emoji_events),
              _metricTile("Students", "199", const Color(0xFFEFF6FF), const Color(0xFF1D4ED8), Icons.people),
              _metricTile("Papers", "1,247", const Color(0xFFFAF5FF), const Color(0xFF7E22CE), Icons.description),
              _metricTile("Projects", "3", const Color(0xFFFFFBEB), const Color(0xFFB45309), Icons.school),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, Color bg, Color text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: text.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: text),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: text.withOpacity(0.9))),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({required IconData icon, required String title, required List items, required VoidCallback onAdd, required String tag}) {
    bool isPub = tag == 'pubs';
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          shape: const Border(),
          leading: Icon(icon, color: const Color(0xFF9333EA)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Text("${items.length} items", style: const TextStyle(fontSize: 11, color: Colors.grey)),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text("Add New", style: TextStyle(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9333EA),
                      minimumSize: const Size(double.infinity, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[200]!, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title'] ?? item['name'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          isPub ? "${item['journal']} • ${item['year']}" : "${item['code']} • ${item['semester']}",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 12),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildResearchInterests() {
    final List<String> interests = ["Machine Learning", "NLP", "Educational Tech", "Deep Learning", "AI Ethics"];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.book, color: Color(0xFF9333EA), size: 20),
                  SizedBox(width: 8),
                  Text("Research Interests", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Icon(Icons.edit, size: 16, color: Color(0xFF9333EA)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: interests.map((interest) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFAF5FF), Color(0xFFFFFBEB)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: Text(interest, style: const TextStyle(color: Color(0xFF7E22CE), fontSize: 11)),
            )).toList(),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Add Interest", style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              side: const BorderSide(color: Colors.grey),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )
        ],
      ),
    );
  }
}