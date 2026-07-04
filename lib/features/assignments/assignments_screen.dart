import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import"../grading/grading_review_dialog.dart";
import '../../core/services/grading_settings_service.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:universal_html/html.dart' as html;

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
  String _sessionTone = GradingSettingsService.instance.feedbackTone;

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

  // void _showReviewDialog(Map sub) {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => GradingReviewDialog(
  //       submission: sub.cast<String, dynamic>(),
  //       onFinalize: (finalGrade) async {
  //         await _handleUpdateGrade(sub['id'], finalGrade);
  //         if (context.mounted) Navigator.pop(context);
  //       },
  //     ),
  //   );
  // }
  void _showReviewDialog(Map sub) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF9333EA)),
      ),
    );

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/submission-details/${sub['id']}'),
      );

      if (mounted) {
        Navigator.pop(context);
      }

      if (response.statusCode == 200) {
        final fullSubmission = json.decode(response.body);
        final gradeReport = fullSubmission['grade_report'] ?? sub['grade_report'] ?? {};
        final matches = gradeReport['plagiarism_matches'] ?? [];

        final mergedSubmission = {
          ...sub,
          'essay_content': fullSubmission['essay_content'] ?? 'No content found.',
          'grade_report': fullSubmission['grade_report'] ?? sub['grade_report'] ?? {},
          'plagiarism_score': fullSubmission['plagiarism_score'] ?? sub['plagiarism_score'] ?? 0,
          'plagiarism_matches': matches,
          'student_name': fullSubmission['student_name'] ?? sub['student_name'],
          'ai_grade': fullSubmission['ai_grade'] ?? sub['ai_grade'],
          'status': fullSubmission['status'] ?? sub['status'] ?? 'ready',
        };

        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => GradingReviewDialog(
              submission: mergedSubmission.cast<String, dynamic>(),
              onFinalize: (finalGrade) async {
                await _handleUpdateGrade(sub['id'], finalGrade);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          );
        }
      } else {
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => GradingReviewDialog(
              submission: {
                ...sub,
                'essay_content': sub['essay_content'] ?? 'Essay content not available.',
              }.cast<String, dynamic>(),
              onFinalize: (finalGrade) async {
                await _handleUpdateGrade(sub['id'], finalGrade);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching submission details: $e")),
        );

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => GradingReviewDialog(
            submission: {
              ...sub,
              'essay_content': sub['essay_content'] ?? 'Error loading content. Please try again.',
            }.cast<String, dynamic>(),
            onFinalize: (finalGrade) async {
              await _handleUpdateGrade(sub['id'], finalGrade);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        );
      }
    }
  }
  Future<void> _downloadFile(Uint8List bytes, String filename) async {
    if (UniversalPlatform.isWeb) {
      // Web: use AnchorElement to trigger download
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile / Desktop: save to temporary directory and share
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Grades for assignment',
      );
      // (Optional) delete the file after sharing
      // await file.delete();
    }
  }
  Future<void> _handleUpdateGrade(int submissionId, double finalGrade) async {
    try {
      final response = await http.put(
        Uri.parse('http://127.0.0.1:8000/update-submission-grade/$submissionId'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"final_grade": finalGrade.toInt()}),
      );

      if (response.statusCode == 200) {
        // Refresh from server so manual_grade and final_grade are accurate
        await fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Grade finalized successfully!"),
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

  Future<void> _handleGradeSubmission(int assignmentId) async {
    PlatformFile? file = await pickFile();
    if (file == null) return;

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

      // request.fields['feedback_tone'] =
      //     GradingSettingsService.instance.feedbackTone;
      request.fields['feedback_tone'] = _sessionTone;

      request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name
      ));

      var response = await request.send();
      if (context.mounted) Navigator.pop(context);
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final Map<String, dynamic> result = json.decode(responseData);

        final int plagiarismScore = result['plagiarism_score'] ?? 0;
        final List matches = result['plagiarism_matches'] ?? [];

        if (plagiarismScore > 30) {
          _showPlagiarismWarning(plagiarismScore, matches);
        }
        // await so the list is refreshed before the snackbar appears
        await fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Grading completed successfully! Plagiarism: $plagiarismScore%",
                style: TextStyle(
                  color: plagiarismScore > 30 ? Colors.red : Colors.green,
                ),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error during grading process.")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection error: $e")),
        );
      }
    }
  }
  Future<void> _handleBatchGrade(int assignmentId) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    await _sendBatchRequest(assignmentId, result.files);
  }

  Future<void> _sendBatchRequest(int assignmentId, List<PlatformFile> files) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF9333EA)),
      ),
    );

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/grade-submission-batch/$assignmentId'),
      );
      // request.fields['feedback_tone'] = GradingSettingsService.instance.feedbackTone;
      request.fields['feedback_tone'] = _sessionTone;
      for (var f in files) {
        request.files.add(http.MultipartFile.fromBytes('files', f.bytes!, filename: f.name));
      }

      var streamedResponse = await request.send();
      if (context.mounted) Navigator.pop(context);

      var responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = json.decode(responseBody);
        _showBatchSummary(context, data['results']);
        await fetchData();
      } else {
        String errorMsg = "Server error (${streamedResponse.statusCode})";
        try {
          final errorJson = json.decode(responseBody);
          if (errorJson['detail'] != null) errorMsg = errorJson['detail'];
        } catch (_) {}
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Batch grading failed: $errorMsg")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      print("Batch request error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection error: $e")),
        );
      }
    }
  }

  void _showBatchSummary(BuildContext context, List results) {
    int success = results.where((r) => r['success'] == true).length;
    int fail = results.length - success;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Batch Grading Complete"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Processed ${results.length} files."),
            Text("Successful: $success"),
            if (fail > 0) Text("Failed: $fail", style: const TextStyle(color: Colors.red)),
            if (fail > 0)
              ...results.where((r) => !r['success']).map((r) =>
                  Text("• ${r['filename']}: ${r['error']}",
                      style: const TextStyle(fontSize: 12, color: Colors.red))
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
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
  Future<void> _exportGrades(int assignmentId, String format) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF9333EA)),
      ),
    );

    try {
      String endpoint;
      String extension;
      if (format == 'excel') {
        endpoint = 'http://127.0.0.1:8000/export-grades-excel/$assignmentId';
        extension = 'xlsx';
      } else {
        endpoint = 'http://127.0.0.1:8000/export-grades-pdf/$assignmentId';
        extension = 'pdf';
      }

      final response = await http.get(Uri.parse(endpoint));
      if (context.mounted) Navigator.pop(context); // close loading

      if (response.statusCode == 200) {
        // Extract filename from Content-Disposition header
        String filename = 'grades.$extension';
        final disposition = response.headers['content-disposition'];
        if (disposition != null) {
          final match = RegExp(r'filename="?([^"]+)"?').firstMatch(disposition);
          if (match != null) {
            filename = match.group(1)!;
          }
        }

        // Download the file
        await _downloadFile(response.bodyBytes, filename);

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Export completed!")),
          );
        }
      } else {
        // Handle server error
        String errorMsg = "Export failed (${response.statusCode})";
        try {
          final errorJson = json.decode(response.body);
          if (errorJson['detail'] != null) errorMsg = errorJson['detail'];
        } catch (_) {}
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      print("Export error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    }
  }


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
              _statCard("Submissions", "$totalSubmissions", Colors.blue),
              const SizedBox(width: 10),
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
            // Edit icon + expand toggle
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF9333EA)),
                  tooltip: "View / Edit Assignment",
                  onPressed: () => _showViewEditAssignmentModal(assign),
                ),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
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

  // ── View / Edit assignment modal ──────────────────────────────────────────
  void _showViewEditAssignmentModal(Map assign) {
    final nameController     = TextEditingController(text: assign['assignment_name'] ?? '');
    final questionController = TextEditingController(text: assign['assignment_question'] ?? '');
    final modelController    = TextEditingController(text: assign['model_answer'] ?? '');
    final rubricController   = TextEditingController(text: assign['rubric'] ?? '');
    bool isModel = assign['is_model_answer'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("View / Edit Assignment",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
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
                      _modalLabel("Question"),
                      _modalTextField(questionController,
                          "Assignment question...", maxLines: 4),
                      const SizedBox(height: 24),
                      // Mode tab selector
                      Row(
                        children: [
                          _tabItem("Model Answer", isModel,
                                  () => setModalState(() => isModel = true)),
                          _tabItem("Rubric", !isModel,
                                  () => setModalState(() => isModel = false)),
                        ],
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      if (isModel)
                        _modalTextField(modelController,
                            "Model answer...", maxLines: 6)
                      else
                        _modalTextField(rubricController,
                            "Rubric criteria...", maxLines: 6),
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
                      child: const Text("Cancel",
                          style: TextStyle(color: Colors.grey)),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _handleUpdateAssignment(
                        assign['id'],
                        nameController.text,
                        questionController.text,
                        isModel,
                        modelController.text,
                        rubricController.text,
                      ),
                      child: const Text("Save Changes",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdateAssignment(
    int assignmentId,
    String name,
    String question,
    bool isModel,
    String modelText,
    String rubricText,
  ) async {
    var request = http.MultipartRequest(
        'PUT', Uri.parse('http://127.0.0.1:8000/assignments/$assignmentId'));
    request.fields['assignment_name']     = name;
    request.fields['assignment_question'] = question;
    request.fields['is_model_answer']     = isModel.toString();
    request.fields['model_answer']        = isModel ? modelText : '';
    request.fields['rubric']              = isModel ? '' : rubricText;

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context);
        fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Assignment updated successfully!"),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update assignment.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget _buildSubmissionList(Map assign, List submissions) {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     const Text("Student Submissions",
          //         style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
          //     ElevatedButton.icon(
          //       style: ElevatedButton.styleFrom(
          //         backgroundColor: const Color(0xFF10B981),
          //         foregroundColor: Colors.white,
          //         elevation: 0,
          //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          //       ),
          //       onPressed: () => _handleGradeSubmission(assign['id']),
          //       icon: const Icon(Icons.add, size: 16),
          //       label: const Text("Grade New"),
          //     )
          //   ],
          // ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Student Submissions",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
              Row(
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'excel') {
                        await _exportGrades(assign['id'], 'excel');
                      } else if (value == 'pdf') {
                        await _exportGrades(assign['id'], 'pdf');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.download, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text("Export", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          Icon(Icons.arrow_drop_down, color: Colors.white),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'excel', child: Text('📊 Excel (.xlsx)')),
                      PopupMenuItem(value: 'pdf', child: Text('📄 PDF')),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'single':
                          await _handleGradeSubmission(assign['id']);
                          break;
                        case 'multiple':
                          await _handleBatchGrade(assign['id']);
                          break;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.add, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text("Grade", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          Icon(Icons.arrow_drop_down, color: Colors.white),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'single', child: Text('Single File')),
                      PopupMenuItem(value: 'multiple', child: Text('Multiple Files')),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Tone selector (new)
          _buildToneSelector(),
          const SizedBox(height: 12),
          if (submissions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text("No submissions yet", style: TextStyle(color: Colors.grey))),
            )
          else
            ...submissions.map((sub) => _buildSubmissionCard(sub)).toList(),
        ],
      ),
    );
  }
  Widget _buildToneSelector() {
    const tones = [
      {'value': 'formal',      'label': 'Formal',      'icon': Icons.school,                  'color': Color(0xFF3B82F6)},
      {'value': 'encouraging', 'label': 'Encouraging',  'icon': Icons.sentiment_satisfied_alt, 'color': Color(0xFF10B981)},
      {'value': 'strict',      'label': 'Strict',       'icon': Icons.gavel,                   'color': Color(0xFFEF4444)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text('Feedback Tone',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: tones.map((t) {
            final val     = t['value'] as String;
            final selected = _sessionTone == val;
            final color   = t['color'] as Color;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _sessionTone = val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.12) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? color : Colors.grey.shade200,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(t['icon'] as IconData, size: 18, color: selected ? color : Colors.grey.shade400),
                      const SizedBox(height: 4),
                      Text(t['label'] as String,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                              color: selected ? color : Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  Widget _buildSubmissionCard(Map sub) {
    double grade = (sub['ai_grade'] ?? 0).toDouble();
    double plagiarism = (sub['plagiarism_score'] ?? 0).toDouble();


    Color plagiarismColor;
    if (plagiarism < 10) {
      plagiarismColor = Colors.green.shade700;
    } else if (plagiarism < 30) {
      plagiarismColor = Colors.orange.shade700;
    } else {
      plagiarismColor = Colors.red.shade700;
    }

    String status = sub['status'] ?? "ready";
    bool isFinalized = status == "Finalized" || status == "graded";
    String date = sub['submitted_at'] ?? DateTime.now().toString();

    String formattedDate = _formatDate(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    sub['student_name'][0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub['student_name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFinalized ? Colors.purple.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFinalized ? Colors.purple.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFinalized ? Icons.check_circle : Icons.star,
                        color: isFinalized ? Colors.purple.shade700 : Colors.green.shade700,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFinalized ? "Finalized" : "Ready for Review",
                        style: TextStyle(
                          color: isFinalized ? Colors.purple.shade700 : Colors.green.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Divider(color: Colors.grey.shade100, height: 1),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isFinalized ? Colors.purple.withOpacity(0.05) : const Color(0xFF9333EA).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.grade, size: 14, color: isFinalized ? Colors.purple.shade700 : const Color(0xFF9333EA)),
                            const SizedBox(width: 4),
                            Text(
                              "AI Grade",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              "${grade.toInt()}%",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: isFinalized ? Colors.purple.shade700 : const Color(0xFF9333EA),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isFinalized
                                    ? Colors.purple.shade100
                                    : (grade >= 50 ? Colors.green.shade100 : Colors.orange.shade100),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isFinalized
                                    ? "✓ Finalized"
                                    : (grade >= 50 ? "✓ Pass" : "⚠️ Needs Work"),
                                style: TextStyle(
                                  color: isFinalized
                                      ? Colors.purple.shade700
                                      : (grade >= 50 ? Colors.green.shade700 : Colors.orange.shade700),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: plagiarism < 15 ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.content_copy, size: 14, color: plagiarism < 15 ? Colors.green.shade700 : Colors.orange.shade700),
                            const SizedBox(width: 4),
                            Text(
                              "Plagiarism",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              "${plagiarism.toInt()}%",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: plagiarism < 15 ? Colors.green.shade700 : Colors.orange.shade700,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              plagiarism < 15 ? Icons.check_circle : Icons.warning,
                              color: plagiarism < 15 ? Colors.green.shade700 : Colors.orange.shade700,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            InkWell(
              onTap: isFinalized ? null : () => _showReviewDialog(sub),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isFinalized
                      ? const LinearGradient(
                    colors: [Colors.grey, Colors.grey],
                  )
                      : const LinearGradient(
                    colors: [Color(0xFF9333EA), Color(0xFF7E22CE)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isFinalized ? null : [
                    BoxShadow(
                      color: const Color(0xFF9333EA).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isFinalized ? "✓ Finalized" : "📄 Review & Finalize",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentRow(Map sub) {
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
  String _formatDate(String dateString) {
    try {
      DateTime utc = DateTime.parse(dateString + 'Z');
      DateTime local = utc.toLocal();
      return "${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateString;
    }
  }
  void _showPlagiarismWarning(int score, List matches) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚠️ Plagiarism Detected"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Plagiarism Score: $score%",
              style: TextStyle(
                color: score > 50 ? Colors.red : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              score > 50
                  ? "High plagiarism detected. The student's work may contain copied content."
                  : "Moderate plagiarism detected. Please review the submission carefully.",
            ),
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                "Similar Submissions:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              ...matches.take(3).map((match) => Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Student: ${match['student_name'] ?? 'Unknown'}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      "${match['similarity']?.toStringAsFixed(1) ?? '0'}%",
                      style: TextStyle(
                        color: match['similarity'] > 30 ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )),
              if (matches.length > 3)
                Text(
                  "... and ${matches.length - 3} more",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
            ],
            const SizedBox(height: 10),
            const Text(
              "Recommendation:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              score > 50
                  ? "• Request a new submission\n• Use a plagiarism checker\n• Consider academic integrity policies"
                  : "• Review the submission\n• Check for proper citations\n• Request clarification if needed",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
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