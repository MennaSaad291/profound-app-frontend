import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class CoursesModuleScreen extends StatefulWidget {
  const CoursesModuleScreen({super.key});

  @override
  State<CoursesModuleScreen> createState() => _CoursesModuleScreenState();
}

class _CoursesModuleScreenState extends State<CoursesModuleScreen> {
  String searchQuery = '';
  List<dynamic> liveCourses = [];
  bool _isLoading = true;
  int? currentUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('id')) {
      currentUserId = args['id'];
      _fetchCourses();
    }
  }

  Future<void> _fetchCourses() async {
    if (currentUserId == null) return;
    final url = Uri.parse('http://localhost:8000/professors/$currentUserId/courses');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          liveCourses = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCourse(int courseId) async {
    final response = await http.delete(Uri.parse('http://localhost:8000/courses/$courseId'));
    if (response.statusCode == 200) {
      _fetchCourses();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Course deleted")));
    }
  }

  void _showAddCourseSheet() {
    final codeCon = TextEditingController();
    final nameCon = TextEditingController();
    PlatformFile? excelFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Add New Course", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: codeCon, decoration: const InputDecoration(labelText: "Course Code")),
              TextField(controller: nameCon, decoration: const InputDecoration(labelText: "Course Name")),
              const SizedBox(height: 20),
              // EXCEL UPLOAD LOGIC
              ElevatedButton.icon(
                onPressed: () async {
                  FilePickerResult? r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
                  if (r != null) setSheetState(() => excelFile = r.files.first);
                },
                icon: const Icon(Icons.upload_file),
                label: Text(excelFile == null ? "Upload Student Excel" : "File: ${excelFile!.name}"),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA), minimumSize: const Size(double.infinity, 50)),
                onPressed: () async {
                  if (excelFile == null || currentUserId == null) return;
                  var request = http.MultipartRequest('POST', Uri.parse('http://localhost:8000/courses-with-students'));
                  request.fields['user_id'] = currentUserId.toString();
                  request.fields['code'] = codeCon.text;
                  request.fields['name'] = nameCon.text;
                  request.fields['semester'] = "Fall 2025";
                  request.files.add(http.MultipartFile.fromBytes('file', excelFile!.bytes!, filename: excelFile!.name));

                  var response = await request.send();
                  if (response.statusCode == 200) {
                    Navigator.pop(context);
                    _fetchCourses();
                  }
                },
                child: const Text("Save Course", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    final filtered = liveCourses.where((c) => 
      c['name'].toLowerCase().contains(searchQuery.toLowerCase()) || 
      c['code'].toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildQuickStats(), // Restored Quick Stats Tiles
            _buildSearchAndAddHeader(), // Restored Search and Add UI
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) => _buildCourseCard(filtered[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    int totalStudents = liveCourses.fold(0, (sum, item) => sum + (item['students'] as int));
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _statTile(Icons.book, "${liveCourses.length}", "Active\nCourses", Colors.purple),
          const SizedBox(width: 10),
          _statTile(Icons.people, "$totalStudents", "Total\nStudents", Colors.amber),
          const SizedBox(width: 10),
          _statTile(Icons.assignment, "25", "Pending\nGrades", Colors.red),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndAddHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Search courses...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.tune, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showAddCourseSheet,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Add New Course", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
      ),
      child: Column(
        children: [
          // Purple Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF9333EA), Color(0xFF7E22CE)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(course['code'] ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                          child: const Text("Active", style: TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      onSelected: (val) {
                        if (val == 'delete') _deleteCourse(course['id']);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'delete', child: Text("Delete Course", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),
                Text(course['name'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Course Progress", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("${course['progress'] ?? 65}%", style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (course['progress'] ?? 65) / 100, backgroundColor: Colors.white24, color: Colors.white),
              ],
            ),
          ),
          // White Details Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    _metaItem(Icons.calendar_today_outlined, course['semester'] ?? "Fall 2025", "Semester"),
                    const Spacer(),
                    _metaItem(Icons.people_outline, "${course['students'] ?? 0}", "Students"),
                  ],
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.access_time, size: 18, color: Color(0xFF9333EA)),
                  const SizedBox(width: 8),
                  Text(course['schedule'] ?? "Mon, Wed 10:00 AM - 11:30 AM", style: const TextStyle(fontSize: 13)),
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(course['room'] ?? "Building A, Room 201", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                const SizedBox(height: 20),
                // Restored Metric Tiles
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _metricTile("8", "Assignments", const Color(0xFFF5F3FF), const Color(0xFF9333EA)),
                  _metricTile("12", "Pending", const Color(0xFFFFFBEB), const Color(0xFFD97706)),
                  _metricTile("65%", "Complete", const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
                ]),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E22CE),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/course_details', arguments: course),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.trending_up, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text("View Course Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String v, String l, Color bg, Color text) => Container(
    width: 95, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [Text(v, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 14)), Text(l, style: TextStyle(color: text, fontSize: 10))]),
  );

  Widget _metaItem(IconData icon, String val, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF9333EA), size: 20),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ],
    );
  }
}