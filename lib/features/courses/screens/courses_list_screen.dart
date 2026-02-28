import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      _fetchCourses(currentUserId!);
    }
  }

  Future<void> _fetchCourses(int userId) async {
    final url = Uri.parse('http://localhost:8000/professors/$userId/courses');
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

  // FUNCTIONAL ADD COURSE METHOD
  void _showAddCourseSheet() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final semesterController = TextEditingController(text: "Fall 2025");
    final studentsController = TextEditingController(text: "0");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Add New Course", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: codeController, decoration: const InputDecoration(labelText: "Course Code (e.g., CS 101)")),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Course Name")),
            TextField(controller: semesterController, decoration: const InputDecoration(labelText: "Semester")),
            TextField(controller: studentsController, decoration: const InputDecoration(labelText: "Number of Students"), keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9333EA),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () async {
                if (currentUserId == null) return;
                
                final response = await http.post(
                  Uri.parse('http://localhost:8000/courses'),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "user_id": currentUserId,
                    "code": codeController.text,
                    "name": nameController.text,
                    "semester": semesterController.text,
                    "students": int.tryParse(studentsController.text) ?? 0,
                    "status": "active"
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context); // Close sheet
                  _fetchCourses(currentUserId!); // Refresh list
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Course added successfully!")));
                }
              },
              child: const Text("Save Course", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F3FF), Colors.white, Color(0xFFFFFBEB)],
        ),
      ),
      child: Column(
        children: [
          _buildStatsHeader(),
          _buildSearchBox(),
          // Updated Button to trigger the sheet
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF9333EA), Color(0xFF7E22CE)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: _showAddCourseSheet, 
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Add New Course", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
              ),
            ),
          ),
          Expanded(child: _buildCourseList()),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _statTile(Icons.book, "${liveCourses.length}", "Active", Colors.purple),
          const SizedBox(width: 10),
          _statTile(Icons.people, "100", "Students", Colors.amber),
          const SizedBox(width: 10),
          _statTile(Icons.assignment, "20", "Pending", Colors.red),
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
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: (val) => setState(() => searchQuery = val),
        decoration: InputDecoration(
          hintText: "Search courses...",
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: const Icon(Icons.filter_list, color: Colors.purple),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildCourseList() {
    final filtered = liveCourses.where((c) => 
      c['name'].toLowerCase().contains(searchQuery.toLowerCase()) || 
      c['code'].toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final course = filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF9333EA), Color(0xFF7E22CE)]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(course['code'] ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                          child: Text(course['status']?.toString().toUpperCase() ?? "ACTIVE", style: const TextStyle(color: Colors.white, fontSize: 10)),
                        )
                      ],
                    ),
                    Text(course['name'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    if (course['status'] == 'active') ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: 0.65, 
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ]
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/course_details', arguments: course),
                        icon: const Icon(Icons.trending_up, size: 16, color: Colors.white),
                        label: const Text("View Course Dashboard", style: TextStyle(color: Colors.white, fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _smallActionBtn(Icons.description, "Materials", Colors.purple),
                        const SizedBox(width: 8),
                        _smallActionBtn(Icons.assignment_turned_in, "Grades", Colors.amber),
                        const SizedBox(width: 8),
                        _smallActionBtn(Icons.people, "${course['students'] ?? 0} Students", Colors.blue),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _smallActionBtn(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}