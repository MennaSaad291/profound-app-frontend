import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CoursesModuleScreen extends StatefulWidget {
  const CoursesModuleScreen({super.key});

  @override
  State<CoursesModuleScreen> createState() => _CoursesModuleScreenState();
}

class _CoursesModuleScreenState extends State<CoursesModuleScreen> {
  String searchQuery = '';
  String filterStatus = 'all';

  final List<Map<String, dynamic>> courses = [
    {
      'id': '1',
      'code': 'CS 401',
      'name': 'Artificial Intelligence',
      'semester': 'Fall 2025',
      'students': 48,
      'status': 'active',
      'schedule': 'Mon, Wed 10:00 AM - 11:30 AM',
      'room': 'Building A, Room 201',
      'progress': 0.65,
      'assignments': 8,
      'pendingGrades': 12,
      'gradient': [const Color(0xFF9333EA), const Color(0xFF7E22CE)],
    },
    {
      'id': '2',
      'code': 'CS 301',
      'name': 'Software Design',
      'semester': 'Fall 2025',
      'students': 52,
      'status': 'active',
      'schedule': 'Tue, Thu 2:00 PM - 3:30 PM',
      'room': 'Building B, Room 105',
      'progress': 0.58,
      'assignments': 10,
      'pendingGrades': 8,
      'gradient': [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
    },
    {
      'id': '4',
      'code': 'CS 501',
      'name': 'Machine Learning',
      'semester': 'Spring 2026',
      'students': 0,
      'status': 'upcoming',
      'schedule': 'TBA',
      'room': 'TBA',
      'progress': 0.0,
      'assignments': 0,
      'pendingGrades': 0,
      'gradient': [const Color(0xFF22C55E), const Color(0xFF15803D)],
    }
  ];

  @override
  Widget build(BuildContext context) {
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
          _buildAddCourseButton(),
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
          _statTile(Icons.book, "3", "Active", Colors.purple),
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

  Widget _buildAddCourseButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF9333EA), Color(0xFF7E22CE)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("Add New Course", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
        ),
      ),
    );
  }

  Widget _buildCourseList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
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
                  gradient: LinearGradient(colors: course['gradient']),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(course['code'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                          child: Text(course['status'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                        )
                      ],
                    ),
                    Text(course['name'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    if (course['status'] == 'active') ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: course['progress'],
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ]
                  ],
                ),
              ),
              _buildCourseActionButtons(course),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseActionButtons(Map<String, dynamic> course) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (course['status'] == 'active')
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
              _smallActionBtn(Icons.people, "Students", Colors.blue),
            ],
          )
        ],
      ),
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