import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';
import 'package:profound_app_frontend/core/constants/api_constants.dart';

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
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final int? userId = args?['id'];

    if (userId != null && profileData == null) {
      _fetchProfile(userId);
    }
  }

  Future<void> _fetchProfile(int userId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/profile/$userId');
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
    final url = Uri.parse('${ApiConstants.baseUrl}$path');
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

  void _showAddInterestSheet() {
    final interestCon = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Add Research Interest", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: interestCon, decoration: const InputDecoration(labelText: "Interest Name")),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA), minimumSize: const Size(double.infinity, 50)),
              onPressed: () => _submitData('/interests', {
                "user_id": profileData!['id'],
                "name": interestCon.text,
              }),
              child: const Text("Save Interest", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  void _showGradProjectSheet({Map<String, dynamic>? existing}) {
    final titleC  = TextEditingController(text: existing?['title'] ?? '');
    final teamC   = TextEditingController(text: existing?['team'] ?? '');
    final yearC   = TextEditingController(text: existing?['academic_year'] ?? '2024-2025');
    final deptC   = TextEditingController(text: existing?['department'] ?? '');
    final isEdit  = existing != null;
    PlatformFile? pickedFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(isEdit ? 'Edit Graduation Project' : 'Add Graduation Project',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
                if (isEdit) IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    await http.delete(Uri.parse('${ApiConstants.baseUrl}/graduation-projects/${existing['id']}'));
                    if (ctx.mounted) Navigator.pop(ctx);
                    _fetchProfile(profileData!['id']);
                  },
                ),
              ]),
              const SizedBox(height: 12),
              _inputField(titleC, 'Project Title'),
              const SizedBox(height: 8),
              _inputField(teamC, 'Team Members (comma separated)'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _inputField(yearC, 'Academic Year (e.g. 2024-2025)')),
                const SizedBox(width: 10),
                Expanded(child: _inputField(deptC, 'Department')),
              ]),
              const SizedBox(height: 12),
              // PDF upload
              GestureDetector(
                onTap: () async {
                  final result = await FilePicker.pickFiles(
                      type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
                  if (result != null) setS(() => pickedFile = result.files.first);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF9333EA).withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFFFAF5FF),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.picture_as_pdf, color: Color(0xFF9333EA), size: 20),
                    const SizedBox(width: 8),
                    Flexible(child: Text(
                      pickedFile != null
                          ? pickedFile!.name
                          : existing?['has_document'] == true
                              ? 'Document uploaded (tap to replace)'
                              : 'Upload Project PDF (optional)',
                      style: GoogleFonts.inter(color: const Color(0xFF9333EA), fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9333EA),
                    minimumSize: const Size(double.infinity, 50)),
                onPressed: () async {
                  final request = http.MultipartRequest(
                    isEdit ? 'PUT' : 'POST',
                    Uri.parse(isEdit
                        ? '${ApiConstants.baseUrl}/graduation-projects/${existing['id']}'
                        : '${ApiConstants.baseUrl}/graduation-projects'),
                  );
                  if (!isEdit) request.fields['user_id'] = profileData!['id'].toString();
                  request.fields['title']         = titleC.text.trim();
                  request.fields['team']          = teamC.text.trim();
                  request.fields['academic_year'] = yearC.text.trim();
                  request.fields['department']    = deptC.text.trim();
                  if (pickedFile != null) {
                    request.files.add(http.MultipartFile.fromBytes(
                        'document', pickedFile!.bytes!, filename: pickedFile!.name));
                  }
                  await request.send();
                  if (ctx.mounted) Navigator.pop(ctx);
                  _fetchProfile(profileData!['id']);
                },
                child: Text(isEdit ? 'Save Changes' : 'Save Project',
                    style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }

  TextField _inputField(TextEditingController c, String label) => TextField(
    controller: c,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );

  void _showAddPubSheet() {
    final tCon = TextEditingController();
    final jCon = TextEditingController();
    final yCon = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Add Publication", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: tCon, decoration: const InputDecoration(labelText: "Title")),
            TextField(controller: jCon, decoration: const InputDecoration(labelText: "Journal")),
            TextField(controller: yCon, decoration: const InputDecoration(labelText: "Year")),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA), minimumSize: const Size(double.infinity, 50)),
              onPressed: () => _submitData('/publications', {
                "user_id": profileData!['id'],
                "title": tCon.text,
                "journal": jCon.text,
                "year": int.tryParse(yCon.text) ?? 2026,
                "citations": 0,
              }),
              child: const Text("Save Publication", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  void _showEditProfileSheet() {
    final nameCon = TextEditingController(text: profileData!['full_name']);
    final deptCon = TextEditingController(text: profileData!['department']);
    final bioCon = TextEditingController(text: profileData!['bio']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Edit Profile", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
            TextField(controller: nameCon, decoration: const InputDecoration(labelText: "Full Name")),
            TextField(controller: deptCon, decoration: const InputDecoration(labelText: "Department")),
            TextField(controller: bioCon, maxLines: 3, decoration: const InputDecoration(labelText: "Bio")),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA), minimumSize: const Size(double.infinity, 50)),
              onPressed: () => _submitData('/profile/update/${profileData!['id']}', {
                "full_name": nameCon.text,
                "department": deptCon.text,
                "bio": bioCon.text,
              }),
              child: const Text("Save Changes", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Container(
      color: const Color(0xFFF8F9FE),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 12),
                  _buildAboutMe(),
                  const SizedBox(height: 12),
                  _buildEngagementMetrics(),
                  const SizedBox(height: 12),
                  _buildCollapsibleSection(
                    icon: Icons.book_outlined,
                    title: "Research & Publications",
                    subtitle: "${(profileData!['publications'] as List).length} publications",
                    items: profileData!['publications'] ?? [],
                    tag: 'pubs',
                    onAdd: _showAddPubSheet,
                  ),
                  _buildCollapsibleSection(
                    icon: Icons.card_membership_outlined,
                    title: "Graduation Projects",
                    subtitle: "${(profileData!['projects'] as List).length} projects",
                    items: profileData!['projects'] ?? [],
                    tag: 'projects',
                    onAdd: () => _showGradProjectSheet(),
                  ),
                  const SizedBox(height: 12),
                  _buildResearchInterests(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)]),
      child: Stack(
        children: [
          Row(
            children: [
              Container(width: 80, height: 80, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF9333EA)), child: const Icon(Icons.person_outline, color: Colors.white, size: 40)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profileData!['full_name'] ?? "", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(children: [const Icon(Icons.school, size: 16, color: Color(0xFF9333EA)), const SizedBox(width: 6), Text("University Professor", style: GoogleFonts.inter(color: const Color(0xFF9333EA), fontWeight: FontWeight.w600, fontSize: 14))]),
                    Text(profileData!['department'] ?? "", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          Positioned(right: 0, top: 0, child: GestureDetector(onTap: _showEditProfileSheet, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF9333EA), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18)))),
        ],
      ),
    );
  }

  Widget _buildAboutMe() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFFAF9FF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF3E8FF))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.menu_book_rounded, color: Color(0xFF9333EA), size: 20), const SizedBox(width: 8), Text("About Me", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15))]),
        const SizedBox(height: 12),
        Text(profileData!['bio'] ?? "", style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87)),
      ]),
    );
  }

  Widget _buildEngagementMetrics() {
    final metrics = profileData!['metrics'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_graph_rounded, color: Color(0xFF9333EA), size: 18),
            const SizedBox(width: 8),
            Text("Engagement Metrics", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 3.8,
          children: [
            _metricTile("Citations", "${metrics['citations'] ?? 0}", const Color(0xFFF0FDF4), const Color(0xFF166534), Icons.chat_bubble_outline_rounded), // FIXED: Bubble icon
            _metricTile("Students", "${metrics['students'] ?? 0}", const Color(0xFFEFF6FF), const Color(0xFF1E40AF), Icons.people_alt_rounded),
            _metricTile("Papers Reviewed", "${metrics['papers'] ?? 0}", const Color(0xFFFAF5FF), const Color(0xFF6B21A8), Icons.article_rounded),
            _metricTile("Projects", "${metrics['projects'] ?? 0}", const Color(0xFFFFFBEB), const Color(0xFF92400E), Icons.school_rounded), // FIXED: Graduation hat
          ],
        ),
      ],
    );
  }

  Widget _metricTile(String label, String value, Color bg, Color text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), 
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: text),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label, 
                  style: GoogleFonts.inter(color: text, fontSize: 10, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: text)),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({required IconData icon, required String title, required String subtitle, required List items, required String tag, required VoidCallback onAdd}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: ExpansionTile(
        leading: Icon(icon, color: const Color(0xFF9333EA)),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              if (tag == 'pubs') Expanded(child: ElevatedButton.icon(onPressed: () async {
                  setState(() => _isLoading = true);
                  await Future.delayed(const Duration(seconds: 1)); 
                  _fetchProfile(profileData!['id']);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Synced with Google Scholar")));
                }, icon: const Icon(Icons.link, size: 16, color: Colors.white), label: const Text("Sync Scholar", style: TextStyle(fontSize: 11, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)))),
              if (tag == 'pubs') const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 16, color: Colors.white), label: Text("Add New", style: const TextStyle(fontSize: 11, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA)))),
            ]),
          ),
          ...items.map((item) {
            if (tag == 'pubs') return _buildPublicationItem(item);
            if (tag == 'projects') return _buildProjectItem(item);
            return const SizedBox();
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPublicationItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.2)), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['title'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.4)),
        const SizedBox(height: 4), Text("${item['journal']} • ${item['year']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4)), child: Row(children: [const Icon(Icons.format_quote, size: 12, color: Color(0xFF166534)), Text(" ${item['citations']}", style: const TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold))])), const SizedBox(width: 8), const Text("Dr. Sarah Johnson +1", style: TextStyle(fontSize: 11, color: Colors.grey))]),
      ]),
    );
  }

  Widget _buildProjectItem(Map<String, dynamic> item) {
    final team = (item['team']?.toString() ?? '')
        .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF9333EA)),
            onPressed: () => _showGradProjectSheet(existing: item),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text(item['academic_year'] ?? item['year'] ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if ((item['department']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(width: 12),
            const Icon(Icons.domain_outlined, size: 12, color: Color(0xFF9333EA)),
            const SizedBox(width: 4),
            Flexible(child: Text(item['department'].toString(),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis)),
          ],
        ]),
        if (team.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: team.map((name) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFFAF5FF), borderRadius: BorderRadius.circular(4)),
            child: Text(name.trim(), style: const TextStyle(color: Color(0xFF7E22CE), fontSize: 10, fontWeight: FontWeight.w500)),
          )).toList()),
        ],
        if (item['has_document'] == true) ...[
          const SizedBox(height: 10),
          Row(children: [
            // ── View in browser ──────────────────────────────────────
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final url = '${ApiConstants.baseUrl}/graduation-projects/${item['id']}/view';
                  html.window.open(url, '_blank');
                },
                icon: const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF1D4ED8)),
                label: const Text('View PDF', style: TextStyle(fontSize: 11, color: Color(0xFF1D4ED8))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1D4ED8)),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ── Force download ───────────────────────────────────────
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final res = await http.get(
                      Uri.parse('${ApiConstants.baseUrl}/graduation-projects/${item['id']}/download'),
                    );
                    if (res.statusCode == 200) {
                      final blob = html.Blob([res.bodyBytes], 'application/pdf');
                      final url = html.Url.createObjectUrlFromBlob(blob);
                      html.AnchorElement(href: url)
                        ..setAttribute('download', '${item['title'] ?? 'project'}.pdf')
                        ..click();
                      html.Url.revokeObjectUrl(url);
                    }
                  } catch (_) {}
                },
                icon: const Icon(Icons.download_rounded, size: 15, color: Colors.white),
                label: const Text('Download', style: TextStyle(fontSize: 11, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9333EA),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _buildResearchInterests() {
    final List<String> interests = List<String>.from(profileData!['interests'] ?? []);
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(Icons.book_rounded, color: Color(0xFF9333EA), size: 20), const SizedBox(width: 8), Text("Research Interests", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15))]), const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF9333EA))]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 10, children: interests.map((interest) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFAF5FF), border: Border.all(color: const Color(0xFFD8B4FE)), borderRadius: BorderRadius.circular(20)), child: Text(interest, style: const TextStyle(color: Color(0xFF7E22CE), fontSize: 11, fontWeight: FontWeight.w500)))).toList()),
        const SizedBox(height: 16), OutlinedButton.icon(onPressed: _showAddInterestSheet, icon: const Icon(Icons.add, size: 16), label: const Text("Add Interest", style: TextStyle(fontSize: 13)), style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44), foregroundColor: Colors.black87, side: const BorderSide(color: Colors.grey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      ]),
    );
  }
}