import 'package:flutter/material.dart';


class Submission {
  final int id;
  final String studentName;
  final String submissionTime;
  final String status;
  final int? aiGrade;
  final int? plagiarismScore;

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
  Submission? selectedSubmission;
  bool showModal = false;

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

  void handleReviewClick(Submission submission) {
    setState(() {
      selectedSubmission = submission;
      showModal = true;
    });
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
              Text(
                'Pending Analysis',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case 'ready':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Text(
                'Ready for Review',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
              Text(
                'Finalized',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Color getPlagiarismColor(int? score) {
    if (score == null) return Colors.grey.shade400;
    if (score < 3) return Colors.green.shade600;
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
            colors: [
              Color(0xFFF5F0FF),
              Colors.white,
              Color(0xFFFFF4E5),
            ],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF9333EA),  // primaryPurple
                    Color(0xFF7E22CE),  // darkPurple
                    Color(0xFFD97706),  // amberOrange
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
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'AI Grading Module',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Software Design Essay',
                            style: TextStyle(
                              color: Color(0xFFE9D5FF),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.jpeg',
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                        ),
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
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: const Color(0xFF9333EA), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Grading Setup',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Rubric Selection
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Rubric',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedRubric,
                                    isExpanded: true,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'default',
                                        child: Text('Standard Essay Rubric'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'technical',
                                        child: Text('Technical Writing Rubric'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'research',
                                        child: Text('Research Paper Rubric'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'new',
                                        child: Text('+ Create New Rubric'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        selectedRubric = value!;
                                      });
                                    },
                                    icon: Icon(Icons.keyboard_arrow_down,
                                        color: Colors.grey.shade500),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // File Upload Zone
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Upload Student Files',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isDragging
                                        ? const Color(0xFF9333EA)
                                        : Colors.grey.shade300,
                                    width: isDragging ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: isDragging
                                      ? const Color(0xFFF5F0FF)
                                      : Colors.grey.shade50,
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(Icons.upload,
                                        size: 32, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Drag and drop files here',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'or',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        const Color(0xFFF3E8FF),
                                        foregroundColor:
                                        const Color(0xFF7E22CE),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text('Browse Files'),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Supported: PDF, DOCX, TXT (Max 10MB)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Run AI Grading Button
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF9333EA),
                                  Color(0xFF7E22CE),
                                  Color(0xFFD97706),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.shade200,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.smart_toy, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Run AI Grading and Analysis',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Assignment Submissions Table
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Student Submissions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          '${submissions.length} total',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Submissions List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: submissions.length,
                      itemBuilder: (context, index) {
                        final submission = submissions[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade200,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Student Name & Time
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    submission.studentName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time,
                                          size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        submission.submissionTime,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Status Badge
                              getStatusBadge(submission.status),
                              const SizedBox(height: 12),

                              // Grades Section
                              if (submission.status != 'pending') ...[
                                Row(
                                  children: [
                                    // AI Grade
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFF5F0FF),
                                              Color(0xFFF0E6FF),
                                            ],
                                          ),
                                          borderRadius:
                                          BorderRadius.circular(8),
                                          border: Border.all(
                                              color: const Color(0xFFE9D5FF)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.smart_toy,
                                                    size: 14,
                                                    color: const Color(
                                                        0xFF7E22CE)),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  'AI Grade',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF7E22CE),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${submission.aiGrade}%',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF581C87),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Plagiarism Score
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                          BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.grey.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.warning_amber,
                                                    size: 14,
                                                    color:
                                                    Colors.grey.shade700),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  'Plagiarism',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF374151),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${submission.plagiarismScore}%',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: getPlagiarismColor(
                                                    submission.plagiarismScore),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Action Button
                              if (submission.status == 'ready')
                                Container(
                                  width: double.infinity,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF9333EA),
                                        Color(0xFF7E22CE),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        handleReviewClick(submission),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.description,
                                            color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Review & Finalize',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              if (submission.status == 'pending')
                                Container(
                                  width: double.infinity,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Awaiting AI Analysis',
                                      style: TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
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

      // Review Modal
      // Note: You'll need to implement GradingReviewModal separately
      // bottomSheet: showModal && selectedSubmission != null
      //     ? GradingReviewModal(
      //         submission: selectedSubmission!,
      //         onClose: () {
      //           setState(() {
      //             showModal = false;
      //             selectedSubmission = null;
      //           });
      //         },
      //         onFinalize: (grade) {
      //           print('Finalized grade: $grade');
      //           setState(() {
      //             showModal = false;
      //             selectedSubmission = null;
      //           });
      //         },
      //       )
      //     : null,
    );
  }
}