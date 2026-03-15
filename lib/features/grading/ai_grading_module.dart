import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Submission {
  final int id;
  final String studentName;
  final String submissionTime;
  String status;
  int? aiGrade;
  int? plagiarismScore;

  Submission({
    required this.id,
    required this.studentName,
    required this.submissionTime,
    required this.status,
    this.aiGrade,
    this.plagiarismScore,
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['id'],
      studentName: json['student_name'] ?? 'Unknown',
      submissionTime: json['submission_time'] ?? '',
      status: json['status'] ?? 'pending',
      aiGrade: json['ai_grade'],
      plagiarismScore: json['plagiarism_score'],
    );
  }
}

class AIGradingModule extends StatefulWidget {
  final VoidCallback onBack;
  // Use 'http://localhost:8000' for Web/Edge
  static const String baseUrl = 'http://127.0.0.1:8000';
  const AIGradingModule({super.key, required this.onBack});

  @override
  State<AIGradingModule> createState() => _AIGradingModuleState();
}

class _AIGradingModuleState extends State<AIGradingModule> {
  String selectedRubric = 'default';
  bool isDragging = false;

  // CHANGED: Use PlatformFile instead of String to store bytes/metadata
  List<PlatformFile> selectedFiles = [];
  bool _isAnalyzing = false;
  List<Submission> submissions = [];

  @override
  void initState() {
    super.initState();
    fetchSubmissions();
  }

  Future<void> fetchSubmissions() async {
    try {
      final response = await http.get(Uri.parse('${AIGradingModule.baseUrl}/submissions'));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          submissions = data.map((s) => Submission.fromJson(s)).toList();
        });
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
  }

  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
      withData: true, // MANDATORY for Web to access file content
    );

    if (result != null) {
      setState(() {
        selectedFiles = result.files; // Store the PlatformFile objects
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${selectedFiles.length} file(s) selected")),
      );
    }
  }

  Future<void> runGradingProcess() async {
    if (selectedFiles.isEmpty) return;

    setState(() => _isAnalyzing = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AIGradingModule.baseUrl}/grade'),
      );

      for (var file in selectedFiles) {
        if (file.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'files',
              file.bytes!,
              filename: file.name,
            ),
          );
        }
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Files uploaded and graded successfully")),
          );
        }
        await fetchSubmissions();
      }
    } catch (e) {
      debugPrint("Grading Error: $e");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void handleReviewClick(Submission submission) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) {
        final TextEditingController gradeController =
        TextEditingController(text: '${submission.aiGrade ?? 0}');

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFF9333EA),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Review Submission',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text(submission.studentName,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Student Submission',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        const SizedBox(height: 12),
                        const Text(
                          "In this essay, I will explore the fundamental principles of software design patterns and their application in modern development...",
                          style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF374151),
                              height: 1.5),
                        ),
                        const Divider(height: 40),
                        const Text('AI Grade Breakdown',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildGradeRow('Content & Understanding', '25/25'),
                        _buildGradeRow('Structure & Organization', '22/25'),
                        _buildGradeRow('Technical Accuracy', '20/25'),
                        _buildGradeRow('Writing Quality', '21/25'),
                        const SizedBox(height: 12),
                        Text('Total AI Grade: ${submission.aiGrade}%',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7E22CE))),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  "This feedback was generated using NLP analysis. Review and edit before sharing with student.",
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF1E40AF)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.amber.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text('Plagiarism Detection',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFEF3C7)),
                          ),
                          child: Text(
                              '${submission.plagiarismScore}% similarity detected. Please review flagged sections.',
                              style: const TextStyle(color: Color(0xFF92400E))),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: const [
                            Icon(Icons.edit_outlined,
                                color: Colors.grey, size: 20),
                            SizedBox(width: 8),
                            Text('Manual Grade Override',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFEF3C7)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  "You can adjust the AI-suggested grade based on your professional judgment...",
                                  style: TextStyle(
                                      fontSize: 13, color: Color(0xFF4B5563))),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Text('Final Grade: ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 80,
                                    height: 40,
                                    child: TextField(
                                      controller: gradeController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.zero,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                            BorderRadius.circular(8)),
                                        fillColor: Colors.white,
                                        filled: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('%'),
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(color: Color(0xFF6B7280))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final int finalScore =
                                int.tryParse(gradeController.text) ?? 0;

                            try {
                              final response = await http.put(
                                Uri.parse('${AIGradingModule.baseUrl}/api/submissions/${submission.id}'),
                                headers: {"Content-Type": "application/json"},
                                body: json.encode({"ai_grade": finalScore, "status": "graded"}),
                              );

                              if (response.statusCode == 200) {
                                await fetchSubmissions();
                                if (context.mounted) Navigator.pop(context);
                              }
                            } catch (e) {
                              debugPrint("Update error: $e");
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9333EA),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.check_circle_outline,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Finalize Grade',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradeRow(String label, String score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF4B5563))),
          Text(score, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget getStatusBadge(String status) {
    switch (status) {
      case 'pending':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.amber.shade700),
              const SizedBox(width: 4),
              Text('Pending Analysis',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        );
      case 'ready':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Text('Ready for Review',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        );
      case 'graded':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Text('Finalized',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
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
            colors: [Color(0xFFF5F0FF), Colors.white, Color(0xFFFFF4E5)],
          ),
        ),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF9333EA),
                    Color(0xFF7E22CE),
                    Color(0xFFD97706)
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 24),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('AI Grading Module',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          Text('Software Design Essay',
                              style: TextStyle(
                                  color: Color(0xFFE9D5FF), fontSize: 14)),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: ClipOval(
                        child: Image.asset('assets/images/logo.jpeg',
                            fit: BoxFit.cover, width: 36, height: 36),
                      ),
                    )
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.auto_awesome,
                                  color: Color(0xFF9333EA), size: 20),
                              SizedBox(width: 8),
                              Text('Grading Setup',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Select Rubric',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF374151))),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedRubric,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                      value: 'default',
                                      child: Text('Standard Essay Rubric')),
                                  DropdownMenuItem(
                                      value: 'technical',
                                      child: Text('Technical Writing Rubric')),
                                  DropdownMenuItem(
                                      value: 'research',
                                      child: Text('Research Paper Rubric')),
                                ],
                                onChanged: (v) =>
                                    setState(() => selectedRubric = v!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Upload Student Files',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF374151))),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: pickFiles,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade50,
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.upload,
                                      size: 32, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'Drag and drop files here or Browse',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF9333EA),
                                Color(0xFF7E22CE),
                                Color(0xFFD97706)
                              ]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              onPressed: _isAnalyzing ? null : runGradingProcess,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _isAnalyzing
                                      ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2))
                                      : const Icon(Icons.smart_toy,
                                      color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isAnalyzing
                                        ? 'Analyzing...'
                                        : 'Run AI Grading and Analysis',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Student Submissions',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        Text('${submissions.length} total',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: submissions.length,
                      itemBuilder: (context, index) {
                        final submission = submissions[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        submission.studentName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(
                                            submission.submissionTime,
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  getStatusBadge(submission.status),
                                ],
                              ),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                              ),

                              // Bottom Section: Grade and Action Button
                              // --- START OF EDITED PART ---
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. AI Grade Section
                                  if (submission.aiGrade != null)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('AI Grade',
                                              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                                          Text('${submission.aiGrade}%',
                                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
                                        ],
                                      ),
                                    ),

                                  if (submission.plagiarismScore != null)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Plagiarism',
                                              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF7ED),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFFFEDD5)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFC2410C)),
                                                const SizedBox(width: 4),
                                                Text('${submission.plagiarismScore}% Match',
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFFC2410C), fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              SizedBox(
                                width: double.infinity,
                                child: submission.status == 'ready'
                                    ? ElevatedButton.icon(
                                  onPressed: () => handleReviewClick(submission),
                                  icon: const Icon(Icons.file_open_outlined, size: 18, color: Colors.white),
                                  label: const Text('Review & Finalize',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF9333EA),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                )
                                    : Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(10)
                                  ),
                                  child: Text(
                                    submission.status == 'graded' ? 'Analysis Complete' : 'Awaiting AI Analysis',
                                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}