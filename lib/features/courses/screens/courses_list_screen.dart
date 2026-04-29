import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

import '../../assignments/assignments_screen.dart';

const String _base = 'http://127.0.0.1:8000';

class CoursesListScreen extends StatefulWidget {
  const CoursesListScreen({super.key});
  @override
  State<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen> {
  List<dynamic> courses = [];
  bool isLoading = true;
  int? userId;
  String searchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    userId = args?['id'];
    if (userId != null && courses.isEmpty) _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('$_base/professors/$userId/courses'));
      if (res.statusCode == 200) {
        setState(() { courses = jsonDecode(res.body); isLoading = false; });
      }
    } catch (_) { setState(() => isLoading = false); }
  }

  Future<void> _deleteCourse(int courseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Course"),
        content: const Text("Are you sure? This will also delete all enrolled students."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await http.delete(Uri.parse('$_base/courses/$courseId'));
    if (res.statusCode == 200) {
      _fetchCourses();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Course deleted"), backgroundColor: Colors.red));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${jsonDecode(res.body)['detail']}"),
          backgroundColor: Colors.red));
    }
  }

  void _showAddEditCourseSheet({Map<String, dynamic>? existing}) {
    final codeCon = TextEditingController(text: existing?['code'] ?? '');
    final nameCon = TextEditingController(text: existing?['name'] ?? '');
    final roomCon = TextEditingController(text: existing?['room'] ?? '');
    final deptCon = TextEditingController(text: existing?['department'] ?? '');

    String selectedSemester = existing?['semester'] ?? '';
    String selectedSchedule = existing?['schedule'] ?? '';
    String status = existing?['status'] ?? 'active';
    final isEdit = existing != null;

    final List<String> semesterOptions = [
      'Fall 2024', 'Spring 2025', 'Summer 2025',
      'Fall 2025', 'Spring 2026', 'Summer 2026',
      'Fall 2026', 'Spring 2027',
    ];

    final List<String> days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu'];
    Set<String> selectedDays = {};
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    // Pre-fill days from existing schedule
    if (selectedSchedule.isNotEmpty && selectedSchedule != 'TBA') {
      final parts = selectedSchedule.split(' ');
      if (parts.isNotEmpty) selectedDays = parts[0].split('/').toSet();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {

        void rebuildSchedule() {
          if (selectedDays.isEmpty) { selectedSchedule = 'TBA'; return; }
          final ordered = days.where((d) => selectedDays.contains(d)).toList();
          String s = ordered.join('/');
          if (startTime != null && endTime != null) {
            String fmt(TimeOfDay t) =>
              '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
            s += ' ${fmt(startTime!)}-${fmt(endTime!)}';
          }
          selectedSchedule = s;
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              // ── Header ──
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(isEdit ? "Edit Course" : "Add New Course",
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 16),

              _field(codeCon, "Course Code *", "e.g., CS401"),
              _field(nameCon, "Course Name *", "e.g., Artificial Intelligence"),

              // ── Semester dropdown ──
              _sectionLabel("Semester *"),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: semesterOptions.contains(selectedSemester) ? selectedSemester : null,
                    hint: const Text("Select semester"),
                    isExpanded: true,
                    items: semesterOptions.map((s) =>
                      DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setModal(() => selectedSemester = val ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Schedule: Days ──
              _sectionLabel("Schedule"),
              const Text("Select days:", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: days.map((day) {
                final picked = selectedDays.contains(day);
                return Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setModal(() {
                      picked ? selectedDays.remove(day) : selectedDays.add(day);
                      rebuildSchedule();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: picked ? const Color(0xFF4F46E5) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(day, textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: picked ? Colors.white : Colors.grey)),
                    ),
                  ),
                ));
              }).toList()),
              const SizedBox(height: 12),

              // ── Schedule: Time ──
              const Text("Select time:", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _timePicker(
                  label: startTime != null
                    ? '${startTime!.hour.toString().padLeft(2,'0')}:${startTime!.minute.toString().padLeft(2,'0')}'
                    : 'Start',
                  picked: startTime != null,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (t != null) setModal(() { startTime = t; rebuildSchedule(); });
                  },
                )),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("→", style: TextStyle(color: Colors.grey, fontSize: 18))),
                Expanded(child: _timePicker(
                  label: endTime != null
                    ? '${endTime!.hour.toString().padLeft(2,'0')}:${endTime!.minute.toString().padLeft(2,'0')}'
                    : 'End',
                  picked: endTime != null,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: endTime ?? const TimeOfDay(hour: 10, minute: 30),
                    );
                    if (t != null) setModal(() { endTime = t; rebuildSchedule(); });
                  },
                )),
              ]),

              // ── Schedule preview ──
              if (selectedSchedule.isNotEmpty && selectedSchedule != 'TBA') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.event, size: 14, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 6),
                    Text(selectedSchedule,
                      style: const TextStyle(
                        color: Color(0xFF4F46E5), fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
              ],
              const SizedBox(height: 16),

              _field(roomCon, "Room", "e.g., Room 201"),
              _field(deptCon, "Department", "e.g., Computer Science"),

              // ── Status ──
              _sectionLabel("Status"),
              const SizedBox(height: 8),
              Row(children: ['active', 'completed', 'upcoming'].map((s) =>
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setModal(() => status = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: status == s ? const Color(0xFF4F46E5) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(s.toUpperCase(), textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: status == s ? Colors.white : Colors.grey)),
                    ),
                  ),
                ))).toList(),
              ),
              const SizedBox(height: 24),

              // ── Submit ──
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    if (codeCon.text.isEmpty || nameCon.text.isEmpty || selectedSemester.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text("Please fill Course Code, Name and Semester"),
                        backgroundColor: Colors.red));
                      return;
                    }
                    final body = {
                      "user_id": userId,
                      "code": codeCon.text.trim(),
                      "name": nameCon.text.trim(),
                      "semester": selectedSemester,
                      "status": status,
                      "schedule": selectedSchedule.isEmpty ? 'TBA' : selectedSchedule,
                      "room": roomCon.text.isEmpty ? 'TBA' : roomCon.text.trim(),
                      "department": deptCon.text.trim(),
                    };
                    if (isEdit) {
                      await http.put(Uri.parse('$_base/courses/${existing!['id']}'),
                        headers: {"Content-Type": "application/json"}, body: jsonEncode(body));
                    } else {
                      await http.post(Uri.parse('$_base/courses'),
                        headers: {"Content-Type": "application/json"}, body: jsonEncode(body));
                    }
                    if (mounted) Navigator.pop(ctx);
                    _fetchCourses();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isEdit ? "Course updated!" : "Course created!"),
                      backgroundColor: const Color(0xFF4F46E5)));
                  },
                  child: Text(isEdit ? "Update Course" : "Create Course",
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 30),
            ]),
          ),
        );
      }),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  );

  Widget _timePicker({required String label, required bool picked, required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: picked ? const Color(0xFFEEF2FF) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: picked ? const Color(0xFF4F46E5) : Colors.transparent),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.access_time, size: 16,
            color: picked ? const Color(0xFF4F46E5) : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: picked ? const Color(0xFF4F46E5) : Colors.grey,
            fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );

  void _showStudentsSheet(Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _StudentsSheet(course: course, baseUrl: _base),
    );
  }

  Widget _field(TextEditingController con, String label, String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: con,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        filled: true, fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );

  List<dynamic> get filteredCourses {
    if (searchQuery.isEmpty) return courses;
    return courses.where((c) =>
      (c['name'] ?? '').toLowerCase().contains(searchQuery.toLowerCase()) ||
      (c['code'] ?? '').toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text("My Courses",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ✅ Single button — icon + label, no FAB
          TextButton.icon(
            onPressed: () => _showAddEditCourseSheet(),
            icon: const Icon(Icons.add_circle, color: Color(0xFF4F46E5), size: 22),
            label: const Text("Add Course",
              style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      // ✅ No floatingActionButton
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => searchQuery = v),
            decoration: InputDecoration(
              hintText: "Search courses...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (!isLoading) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _statPill("${courses.length}", "Total", const Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            _statPill("${courses.where((c) => c['status'] == 'active').length}",
              "Active", const Color(0xFF10B981)),
            const SizedBox(width: 8),
            _statPill(
              "${courses.fold(0, (sum, c) => sum + (c['students'] as int? ?? 0))}",
              "Students", const Color(0xFFD97706)),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
            : filteredCourses.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _fetchCourses,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredCourses.length,
                    itemBuilder: (ctx, i) {
                      final course = filteredCourses[i];
                      return InkWell(
                          onTap: () {
                            final id = course['id'];

                            if (id == null || id == 0) {
                              print("Invalid course ID: $id");
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AssignmentsScreen(
                                  courseId: id,
                                  courseName: course['name'],
                                )
                              ),
                            );
                          },
                        // This keeps your existing UI exactly as is
                        child: _buildCourseCard(course),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _statPill(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
      ]),
    ),
  );

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final status = course['status'] ?? 'active';
    final statusColors = {
      'active':    [const Color(0xFFD1FAE5), const Color(0xFF065F46)],
      'completed': [const Color(0xFFE0E7FF), const Color(0xFF3730A3)],
      'upcoming':  [const Color(0xFFFEF3C7), const Color(0xFF92400E)],
    };
    final colors = statusColors[status] ?? statusColors['active']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.school, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course['code'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(course['name'] ?? '',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: colors[0], borderRadius: BorderRadius.circular(20)),
              child: Text(status.toUpperCase(),
                style: TextStyle(color: colors[1], fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              _infoChip(Icons.calendar_today, course['semester'] ?? 'N/A'),
              const SizedBox(width: 16),
              _infoChip(Icons.people, "${course['students'] ?? 0} students"),
            ]),
            if ((course['schedule'] ?? 'TBA') != 'TBA') ...[
              const SizedBox(height: 6),
              Row(children: [
                _infoChip(Icons.access_time, course['schedule'] ?? ''),
                const SizedBox(width: 16),
                _infoChip(Icons.room, course['room'] ?? 'TBA'),
              ]),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _actionBtn(Icons.people_outline, "Students",
                const Color(0xFF10B981), () => _showStudentsSheet(course))),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn(Icons.bar_chart, "Analytics",
                const Color(0xFF4F46E5),
                () => Navigator.pushNamed(context, '/course_details', arguments: course))),
              const SizedBox(width: 8),
              _iconBtn(Icons.edit_outlined, const Color(0xFF6B7280),
                () => _showAddEditCourseSheet(existing: course)),
              const SizedBox(width: 4),
              _iconBtn(Icons.delete_outline, Colors.red, () => _deleteCourse(course['id'])),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]);

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
    ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
    InkWell(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 18),
    ));

  Widget _buildEmpty() =>
    Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text("No courses yet", style: GoogleFonts.inter(fontSize: 18, color: Colors.grey)),
      const SizedBox(height: 8),
      const Text("Tap 'Add Course' at the top to get started",
        style: TextStyle(color: Colors.grey)),
    ]));
}

// ─────────────────────────────────────────────────────────────────
// Students Sheet
// ─────────────────────────────────────────────────────────────────
class _StudentsSheet extends StatefulWidget {
  final Map<String, dynamic> course;
  final String baseUrl;
  const _StudentsSheet({required this.course, required this.baseUrl});
  @override
  State<_StudentsSheet> createState() => _StudentsSheetState();
}

class _StudentsSheetState extends State<_StudentsSheet> {
  List<dynamic> students = [];
  bool isLoading = true;
  bool isUploading = false;

  @override
  void initState() { super.initState(); _fetchStudents(); }

  Future<void> _fetchStudents() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/courses/${widget.course['id']}/students'));
      if (res.statusCode == 200) {
        setState(() { students = jsonDecode(res.body); isLoading = false; });
      }
    } catch (_) { setState(() => isLoading = false); }
  }

  Future<void> _uploadExcel() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv']);
    if (result == null || result.files.single.bytes == null) return;
    setState(() => isUploading = true);
    try {
      final file = result.files.single;
      final request = http.MultipartRequest('POST',
        Uri.parse('${widget.baseUrl}/courses/${widget.course['id']}/upload-students'));
      request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
      final res = await http.Response.fromStream(await request.send());
      final data = jsonDecode(res.body);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data['message'] ?? 'Upload complete'),
        backgroundColor: res.statusCode == 200 ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ));
      if (res.statusCode == 200) _fetchStudents();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red));
    } finally { setState(() => isUploading = false); }
  }

  Future<void> _deleteStudent(int studentId) async {
    await http.delete(Uri.parse(
      '${widget.baseUrl}/courses/${widget.course['id']}/students/$studentId'));
    _fetchStudents();
  }

  void _showAddStudentDialog() {
    final idCon = TextEditingController();
    final nameCon = TextEditingController();
    final deptCon = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Student"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: idCon,
            decoration: const InputDecoration(labelText: "Student ID")),
          const SizedBox(height: 8),
          TextField(controller: nameCon,
            decoration: const InputDecoration(labelText: "Full Name")),
          const SizedBox(height: 8),
          TextField(controller: deptCon,
            decoration: const InputDecoration(labelText: "Department (optional)")),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () async {
              if (idCon.text.isEmpty || nameCon.text.isEmpty) return;
              final res = await http.post(
                Uri.parse('${widget.baseUrl}/courses/${widget.course['id']}/students'),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "student_id": idCon.text, "name": nameCon.text,
                  "department": deptCon.text, "course_id": widget.course['id']
                }),
              );
              if (mounted) Navigator.pop(ctx);
              if (res.statusCode == 200) {
                _fetchStudents();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Student added!"),
                    backgroundColor: Colors.green));
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(jsonDecode(res.body)['detail'] ?? 'Error'),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
      expand: false,
      builder: (ctx, scroll) => Column(children: [
        Container(margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),

        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Students",
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20)),
            Text("${widget.course['code']} · ${students.length} enrolled",
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ])),
          if (isUploading)
            const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(onPressed: _uploadExcel,
              icon: const Icon(Icons.upload_file, color: Color(0xFF10B981)),
              tooltip: "Upload Excel/CSV"),
          IconButton(onPressed: _showAddStudentDialog,
            icon: const Icon(Icons.person_add, color: Color(0xFF4F46E5)),
            tooltip: "Add manually"),
        ])),

        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Color(0xFF10B981), size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                "Upload Excel/CSV: columns student_id, name, department (optional)",
                style: TextStyle(color: Color(0xFF065F46), fontSize: 11),
              )),
            ]),
          ),
        ),
        const Divider(),

        Expanded(child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : students.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text("No students enrolled yet",
                  style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                const Text("Add manually or upload Excel",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]))
            : ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: students.length,
                itemBuilder: (ctx, i) {
                  final s = students[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                        child: Text(
                          s['name'].toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text("ID: ${s['student_id']} • ${s['department'] ?? 'N/A'}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ])),
                      IconButton(
                        onPressed: () => _deleteStudent(s['id']),
                        icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red, size: 20),
                      ),
                    ]),
                  );
                },

              ),
        ),
      ]),
    );
  }
}
