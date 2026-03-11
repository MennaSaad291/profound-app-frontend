import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

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
}

class AIGradingModule extends StatefulWidget {
  final VoidCallback onBack;

  const AIGradingModule({super.key, required this.onBack});

  @override
  State<AIGradingModule> createState() => _AIGradingModuleState();
}

class _AIGradingModuleState extends State<AIGradingModule> {
  String selectedRubric = 'default';
  bool isDragging = false;
  List<String> selectedFiles = [];
  bool _isAnalyzing = false;

  List<Submission> submissions = [
    Submission(
      id: 1,
      studentName: 'Sarah Johnson',
      submissionTime: '2025-12-01 14:30',
      status: 'ready',
      aiGrade: 88,
      plagiarismScore: 2,
    ),
    Submission(
      id: 2,
      studentName: 'Michael Chen',
      submissionTime: '2025-12-01 15:45',
      status: 'ready',
      aiGrade: 92,
      plagiarismScore: 0,
    ),
    Submission(
      id: 3,
      studentName: 'Emily Rodriguez',
      submissionTime: '2025-12-01 16:20',
      status: 'ready',
      aiGrade: 76,
      plagiarismScore: 5,
    ),
    Submission(
      id: 4,
      studentName: 'David Park',
      submissionTime: '2025-12-02 09:15',
      status: 'pending',
      aiGrade: null,
      plagiarismScore: null,
    ),
    Submission(
      id: 5,
      studentName: 'Jessica Williams',
      submissionTime: '2025-12-02 10:30',
      status: 'pending',
      aiGrade: null,
      plagiarismScore: null,
    ),
  ];

  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
    );

    if (result != null) {
      setState(() {
        selectedFiles = result.files.map((f) => f.name).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${selectedFiles.length} file(s) selected")),
      );
    }
  }

  Future<void> runGradingProcess() async {
    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No files selected to grade")),
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      for (var sub in submissions) {
        if (sub.status == 'pending') {
          sub.status = 'ready';
          sub.aiGrade = 85;
          sub.plagiarismScore = 4;
        }
      }
      _isAnalyzing = false;
      selectedFiles.clear();
    });
  }

  // THE UPDATED REVIEW MODAL (Matching your images)
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
                // Modal Header (Image 1 Style)
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
                          "In this essay, I will explore the fundamental principles of software design patterns and their application in modern development. Design patterns are reusable solutions to commonly occurring problems in software design. They represent best practices and can speed up the development process by providing tested paradigms.\n\n"
                              "The Singleton pattern ensures a class has only one instance and provides a global point of access to it. This is particularly useful for managing shared resources such as database connections or configuration settings. The Factory pattern, on the other hand, provides an interface for creating objects in a superclass, but allows subclasses to alter the type of objects that will be created.\n\n"
                              "Model-View-Controller (MVC) is an architectural pattern that separates an application into three main logical components. This separation of concerns makes the code more maintainable and scalable. The Observer pattern is crucial for implementing distributed event handling systems, where an object maintains a list of dependents and notifies them of state changes.\n\n"
                              "In conclusion, understanding and properly implementing design patterns is essential for creating robust, maintainable, and scalable software systems.",
                          style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF374151),
                              height: 1.5),
                        ),
                        const Divider(height: 40),

                        // AI Grade Breakdown
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

                        // AI-Generated Feedback NLP Warning
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

                        // Plagiarism Detection
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

                        // Manual Grade Override
                        const Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            const Text('Manual Grade Override',
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
                                  "You can adjust the AI-suggested grade based on your professional judgment and additional criteria not captured by the automated analysis.",
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

                // Footer Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                    Border(top: BorderSide(color: Colors.grey.shade200)),
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
                          onPressed: () {
                            setState(() {
                              submission.status = 'graded';
                              submission.aiGrade =
                                  int.tryParse(gradeController.text) ??
                                      submission.aiGrade;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9333EA),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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

  Color getPlagiarismColor(int? score) {
    if (score == null) return Colors.grey.shade400;
    if (score < 3) return const Color(0xFF10B981);
    if (score < 10) return Colors.amber.shade600;
    return Colors.red.shade600;
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
            // Original Header with Logo
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9333EA), Color(0xFF7E22CE), Color(0xFFD97706)],
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
                    // Grading Setup Card
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
                            children: [
                              const Icon(Icons.auto_awesome,
                                  color: Color(0xFF9333EA), size: 20),
                              const SizedBox(width: 8),
                              const Text('Grading Setup',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Dropdown
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
                                onChanged: (v) => setState(() => selectedRubric = v!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Upload Box
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
                                  const Text('Drag and drop files here or Browse',
                                      style: TextStyle(
                                          fontSize: 14, color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Analyze Button
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
                    // Submission List Header
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
                    // Submissions
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: submissions.length,
                      itemBuilder: (context, index) {
                        final submission = submissions[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(submission.studentName,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.access_time,
                                    size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(submission.submissionTime,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500)),
                              ]),
                              const SizedBox(height: 12),
                              getStatusBadge(submission.status),
                              const SizedBox(height: 12),
                              if (submission.status != 'pending') ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSmallGradeCard(
                                          'AI Grade',
                                          '${submission.aiGrade}%',
                                          const Color(0xFFF5F0FF),
                                          const Color(0xFF7E22CE)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSmallGradeCard(
                                          'Plagiarism',
                                          '${submission.plagiarismScore}%',
                                          Colors.grey.shade50,
                                          getPlagiarismColor(
                                              submission.plagiarismScore)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (submission.status == 'ready')
                                SizedBox(
                                  width: double.infinity,
                                  height: 45,
                                  child: ElevatedButton(
                                    onPressed: () => handleReviewClick(submission),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF9333EA),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(8))),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.description,
                                            color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Text('Review & Finalize',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildSmallGradeCard(String label, String value, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: textCol, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 22, color: textCol, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}