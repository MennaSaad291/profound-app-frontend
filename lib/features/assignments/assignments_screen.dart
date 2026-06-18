import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import"../grading/grading_review_dialog.dart";
import '../../core/services/grading_settings_service.dart';

class AssignmentsScreen extends StatefulWidget {
  final int courseId;
  final String courseName;

  const AssignmentsScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  List assignments = [];
  bool isLoading = true;
  int? expandedAssignmentId;

  @override
  void initState() {
    super.initState();
    fetchData();
  }
  int get totalSubmissions {
    int count = 0;
    for (var assign in assignments) {
      List submissions = assign['submissions'] ?? [];
      count += submissions.length;
    }
    return count;
  }

  int get totalGraded {
    int count = 0;
    for (var assign in assignments) {
      List submissions = assign['submissions'] ?? [];
      count += submissions.where((sub) => sub['ai_grade'] != null).length;
    }
    return count;
  }

  void _showReviewDialog(Map sub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GradingReviewDialog(
        submission: sub.cast<String, dynamic>(),
        onFinalize: (finalGrade) async {
          // await the HTTP call so fetchData runs AFTER the server confirms
          await _handleUpdateGrade(sub['id'], finalGrade);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
  Future<void> _handleUpdateGrade(int submissionId, double finalGrade) async {
    try {
      final response = await http.put(
        Uri.parse('http://127.0.0.1:8000/update-submission-grade/$submissionId'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"final_grade": finalGrade.toInt()}),
      );

      if (response.statusCode == 200) {
        // Refresh AFTER the server has confirmed the write
        await fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Grade updated successfully!"),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        throw Exception("Server returned ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating grade: $e")),
        );
      }
    }
  }
  Future<void> fetchData() async {
    try {
      final res = await http.get(Uri.parse(
          'http://127.0.0.1:8000/assignments-with-submissions/${widget.courseId}'));
      if (res.statusCode == 200) {
        setState(() {
          assignments = json.decode(res.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<PlatformFile?> pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
      withData: true,
    );
    return result?.files.first;
  }

  // ---------------- GRADING LOGIC ----------------
  Future<void> _handleGradeSubmission(int assignmentId) async {
    PlatformFile? file = await pickFile();
    if (file == null) return;

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF9333EA)),
      ),
    );

    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('http://127.0.0.1:8000/grade-submission/$assignmentId'));

      // Fix 1: send the professor's saved feedback tone so the backend
      // uses it instead of always defaulting to "formal".
      request.fields['feedback_tone'] =
          GradingSettingsService.instance.feedbackTone;

      request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name
      ));

      var response = await request.send();
      Navigator.pop(context); // Remove loading

      if (response.statusCode == 200) {
        fetchData(); // Refresh list to see new submission
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Grading completed successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error during grading process.")),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildGradientHeader(),
              const SizedBox(height: 55),
              _buildAssignmentList(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- CONSOLIDATED CREATE MODAL ----------------
  void _showCreateAssignmentModal() {
    final nameController = TextEditingController();
    final questionController = TextEditingController();
    final modelController = TextEditingController();
    final rubricController = TextEditingController();
    final pointsController = TextEditingController();

    PlatformFile? questionFile;
    PlatformFile? modelFile;
    PlatformFile? rubricFile;
    int activeTab = 0; // 0 for Model, 1 for Rubric

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Create New Assignment",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close))
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _modalLabel("Title"),
                      _modalTextField(nameController, "Assignment title..."),
                      const SizedBox(height: 16),
                      _modalLabel("Question (Text or File)"),
                      _modalTextField(questionController, "Enter assignment question text...",
                          maxLines: 3),
                      const SizedBox(height: 10),
                      _uploadBox(questionFile?.name ?? "Upload Question File (PDF/Docx/Txt)",
                          const Color(0xFF6366F1), () async {
                            var f = await pickFile();
                            if (f != null) setModalState(() => questionFile = f);
                          }),
                      const SizedBox(height: 16),
                      _modalLabel("Points"),
                      _modalTextField(pointsController, "100", isNumber: true),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _tabItem("Model Answer", activeTab == 0,
                                  () => setModalState(() => activeTab = 0)),
                          _tabItem("Rubric", activeTab == 1,
                                  () => setModalState(() => activeTab = 1)),
                        ],
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      if (activeTab == 0) ...[
                        _modalTextField(modelController, "Enter model answer text...",
                            maxLines: 5),
                        const SizedBox(height: 12),
                        _uploadBox(modelFile?.name ?? "Upload Model File",
                            const Color(0xFF9333EA), () async {
                              var f = await pickFile();
                              if (f != null) setModalState(() => modelFile = f);
                            }),
                      ] else ...[
                        _modalTextField(rubricController, "Enter grading rubric criteria...",
                            maxLines: 5),
                        const SizedBox(height: 12),
                        _uploadBox(rubricFile?.name ?? "Upload Rubric File",
                            const Color(0xFF9333EA), () async {
                              var f = await pickFile();
                              if (f != null) setModalState(() => rubricFile = f);
                            }),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9333EA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _handleCreate(
                          nameController.text,
                          questionController.text,
                          questionFile,
                          activeTab == 0,
                          modelController.text,
                          rubricController.text,
                          modelFile,
                          rubricFile),
                      child: const Text("Create Assignment",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- BACKEND LOGIC ----------------
  Future<void> _handleCreate(
      String name,
      String question,
      PlatformFile? qFile,
      bool isModel,
      String modelText,
      String rubricText,
      PlatformFile? mFile,
      PlatformFile? rFile) async {
    var request =
    http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:8000/assignments'));
    request.fields['assignment_name'] = name;
    request.fields['course_id'] = widget.courseId.toString();
    request.fields['assignment_question'] = question;
    request.fields['is_model_answer'] = isModel.toString();

    if (qFile?.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes('assignment_file', qFile!.bytes!,
          filename: qFile.name));
    }

    if (isModel) {
      request.fields['model_answer'] = modelText;
      if (mFile?.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('model_answer_file', mFile!.bytes!,
            filename: mFile.name));
      }
    } else {
      request.fields['rubric'] = rubricText;
      if (rFile?.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('rubric_file', rFile!.bytes!,
            filename: rFile.name));
      }
    }

    var response = await request.send();
    if (response.statusCode == 200) {
      Navigator.pop(context);
      fetchData();
    }
  }

  // ---------------- UI HELPERS ----------------

  Widget _uploadBox(String label, Color themeColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: themeColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: themeColor.withOpacity(0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, color: themeColor, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: themeColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _modalLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(text,
        style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF374151))),
  );

  Widget _modalTextField(TextEditingController controller, String hint,
      {int maxLines = 1, bool isNumber = false}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _tabItem(String title, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: isActive ? const Color(0xFF9333EA) : Colors.transparent, width: 2))),
        child: Text(title,
            style: TextStyle(
                color: isActive ? const Color(0xFF9333EA) : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildGradientHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 100),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9333EA), Color(0xFF8B5CF6), Color(0xFFFB923C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _backButton(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Assignments",
                            style: TextStyle(
                                color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                        Text(widget.courseName,
                            style: const TextStyle(color: Colors.white70, fontSize: 15)),
                      ],
                    ),
                  ),
                  _createButton(),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -35,
          left: 24,
          right: 24,
          child: Row(
            children: [
              _statCard("Assignments", "${assignments.length}", Colors.purple),
              const SizedBox(width: 10),
              // Use the getter here
              _statCard("Submissions", "$totalSubmissions", Colors.blue),
              const SizedBox(width: 10),
              // Use the getter here
              _statCard("Graded", "$totalGraded", const Color(0xFF10B981)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: assignments.length,
        itemBuilder: (context, index) {
          final assign = assignments[index];
          final bool isExpanded = expandedAssignmentId == assign['id'];
          return _assignmentCard(assign, isExpanded);
        },
      ),
    );
  }

  Widget _assignmentCard(Map assign, bool isExpanded) {
    List submissions = assign['submissions'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF9333EA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.assignment, color: Color(0xFF9333EA)),
            ),
            title: Text(assign['assignment_name'],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${submissions.length} Submissions"),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(
                    () => expandedAssignmentId = isExpanded ? null : assign['id']),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            _buildSubmissionList(assign, submissions),
          ]
        ],
      ),
    );
  }

  Widget _buildSubmissionList(Map assign, List submissions) {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Student Submissions",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _handleGradeSubmission(assign['id']),
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Grade New"),
              )
            ],
          ),
          const SizedBox(height: 12),
          if (submissions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text("No submissions yet", style: TextStyle(color: Colors.grey))),
            )
          else
            ...submissions.map((sub) => _studentRow(sub)).toList(),
        ],
      ),
    );
  }

  Widget _studentRow(Map sub) {
    // final_grade = manual_grade if professor overrode, else ai_grade
    final int? finalGrade = sub['final_grade'];
    final int? aiGrade    = sub['ai_grade'];
    final bool overridden = sub['manual_grade'] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue.shade50,
            child: Text(sub['student_name'][0].toUpperCase(),
                style: const TextStyle(fontSize: 12, color: Colors.blue)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub['student_name'],
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                // Show original AI score underneath when professor overrode it
                if (overridden)
                  Text(
                    "AI: $aiGrade%  →  Final: $finalGrade%",
                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                  )
                else
                  const Text("Status: graded",
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          // Grade badge — orange if professor-adjusted, purple if AI only
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: overridden
                  ? Colors.orange.withOpacity(0.12)
                  : const Color(0xFF9333EA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$finalGrade%",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: overridden ? Colors.orange : const Color(0xFF9333EA),
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            onPressed: () => _showReviewDialog(sub),
          ),
        ],
      ),
    );
  }

  Widget _backButton() => InkWell(
    onTap: () => Navigator.pop(context),
    child: const Row(children: [
      Icon(Icons.chevron_left, color: Colors.white, size: 20),
      Text(" Back to Course",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500))
    ]),
  );

  Widget _createButton() => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF9333EA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    onPressed: _showCreateAssignmentModal,
    icon: const Icon(Icons.add, size: 20),
    label: const Text("Create Assignment", style: TextStyle(fontWeight: FontWeight.bold)),
  );

  Widget _statCard(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}