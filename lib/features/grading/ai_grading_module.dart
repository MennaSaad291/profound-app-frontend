import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../grading/grading_review_dialog.dart';
import '../../core/services/grading_settings_service.dart';

class AiGradingModule extends StatefulWidget {
  final int userId;
  const AiGradingModule({super.key, required this.userId});
  @override
  State<AiGradingModule> createState() => _AiGradingModuleState();
}

class _AiGradingModuleState extends State<AiGradingModule> {
  String selectedMode = 'MODEL';
  bool isAnalyzing = false;
  bool isLoading = true;
  String currentFileName = "Manual Entry";
  String _sessionTone = GradingSettingsService.instance.feedbackTone;
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _studentController = TextEditingController();
  List<Map<String, dynamic>> resultsList = [];

  final Color primaryPurple = const Color(0xFF9333EA);
  final List<Color> actionGradient = [const Color(0xFF9333EA), const Color(0xFF7E22CE)];
  final List<Color> bgGradient = [const Color(0xFFF5F3FF), Colors.white, const Color(0xFFFFFBEB)];

  Future<void> _pickFile(TextEditingController controller) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
      withData: true,
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      setState(() {
        currentFileName = file.name.split('.').first;
        controller.text = "Extracting text from ${file.name}...";
      });

      try {
        var request = http.MultipartRequest(
            'POST',
            Uri.parse('http://127.0.0.1:8000/extract-text')
        );
        request.files.add(http.MultipartFile.fromBytes(
            'file',
            file.bytes!,
            filename: file.name
        ));

        var response = await http.Response.fromStream(await request.send());

        if (response.statusCode == 200) {
          setState(() {
            controller.text = json.decode(response.body)['extracted_text'];
          });
        } else {
          setState(() => controller.text = "Error: Text extraction failed.");
        }
      } catch (e) {
        setState(() => controller.text = "Connection error. Check backend.");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint("=== AI Grading Module Initialized with User ID: ${widget.userId} ===");
    _loadSavedSubmissions();
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateString;
    }
  }

  // --- LOAD SAVED SUBMISSIONS FROM DATABASE ---
  Future<void> _loadSavedSubmissions() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/submissions/general?user_id=${widget.userId}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          resultsList = data.map((sub) => {
            "id": sub['id'],
            "student_name": sub['student_name'] ?? "Unknown",
            "title": sub['student_name'] ?? "Unknown",
            "ai_grade": sub['ai_grade'] ?? 0,
            "grade": sub['ai_grade'] ?? 0,
            "summary": sub['grade_report']?['summary'] ?? "Analysis complete.",
            "essay_content": sub['essay_content'] ?? "",
            "date": _formatDate(sub['submission_time'] ?? DateTime.now().toString()),
            "plagiarism": sub['plagiarism_score'] ?? 0,
            "plagiarism_score": sub['plagiarism_score'] ?? 0,
            "grade_report": sub['grade_report'] ?? {
              "summary": "Analysis complete.",
              "detected_language": "English",
            },
            "status": sub['status'] == 'graded' ? "Finalized" : "Ready for Review",
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error loading submissions: $e");
      setState(() => isLoading = false);
    }
  }
  // Future<void> _handleGrading() async {
  //   if (_refController.text.isEmpty || _studentController.text.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Please provide reference and student content")),
  //     );
  //     return;
  //   }
  //
  //   setState(() => isAnalyzing = true);
  //
  //   try {
  //     final response = await http.post(
  //       Uri.parse('http://127.0.0.1:8000/analyze-general-submission'),
  //       headers: {"Content-Type": "application/json"},
  //       body: json.encode({
  //         "student_text": _studentController.text,
  //         "mode": selectedMode,
  //         "reference_content": _refController.text,
  //         "feedback_tone": _sessionTone,
  //       }),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       setState(() {
  //         resultsList.insert(0, {
  //           "title":             currentFileName,
  //           "grade":             data['score_out_of_100'] ?? 0,
  //           "summary":           data['summary'] ?? "Analysis complete.",
  //           "strengths":         data['strengths'] ?? [],
  //           "areas_for_improvement": data['areas_for_improvement'] ?? [],
  //           "error_categories":  data['error_categories'] ?? {},
  //           "recommendation":    data['recommendation'] ?? "",
  //           "feedback_tone":     data['feedback_tone'] ?? "formal",
  //           "time":              "Just now",
  //         });
  //       });
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
  //   } finally {
  //     setState(() => isAnalyzing = false);
  //   }
  // }
  Future<void> _handleGrading() async {
    if (_refController.text.isEmpty || _studentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide reference and student content")),
      );
      return;
    }

    setState(() => isAnalyzing = true);
    try {
      // 1. Analyze via Backend Endpoint (including user_id and feedback_tone)
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/analyze-general-submission?user_id=${widget.userId}'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "student_text": _studentController.text,
          "mode": selectedMode,
          "reference_content": _refController.text,
          "feedback_tone": _sessionTone, // Added from second code snippet
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiGrade = data['score_out_of_100'] ?? 0;
        final plagiarismScore = data['plagiarism'] ?? 0;
        final summary = data['summary'] ?? "Analysis complete.";
        final detectedLanguage = data['detected_language'] ?? "English";
        final strengths = data['strengths'] ?? [];
        final improvements = data['improvements'] ?? data['areas_for_improvement'] ?? [];
        final matches = data['plagiarism_matches'] ?? [];

        // Additional metrics captured from the second code snippet
        final errorCategories = data['error_categories'] ?? {};
        final recommendation = data['recommendation'] ?? "";
        final analyticalTone = data['feedback_tone'] ?? "formal";

        // Show plagiarism warning if score is high
        if (plagiarismScore > 30) {
          _showPlagiarismWarning(plagiarismScore, matches);
        }

        // 2. Save the detailed report structure to the Database
        final saveResponse = await http.post(
          Uri.parse('http://127.0.0.1:8000/submissions/general'),
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "user_id": widget.userId,
            "student_name": currentFileName,
            "essay_content": _studentController.text,
            "ai_grade": aiGrade,
            "plagiarism_score": plagiarismScore,
            "grade_report": {
              "summary": summary,
              "detected_language": detectedLanguage,
              "strengths": strengths,
              "improvements": improvements,
              "plagiarism_matches": matches,
              "error_categories": errorCategories,
              "recommendation": recommendation,
              "feedback_tone": analyticalTone,
            },
            "status": "ready",
          }),
        );

        if (saveResponse.statusCode == 200 || saveResponse.statusCode == 201) {
          final savedData = json.decode(saveResponse.body);

          // 3. Update the local UI state with all merged properties
          setState(() {
            resultsList.insert(0, {
              "id": savedData['id'],
              "student_name": currentFileName,
              "title": currentFileName,
              "ai_grade": aiGrade,
              "grade": aiGrade,
              "summary": summary,
              "essay_content": _studentController.text,
              "date": _getCurrentDate(),
              "time": "Just now",
              "plagiarism": plagiarismScore,
              "plagiarism_score": plagiarismScore,
              "plagiarism_matches": matches,
              "strengths": strengths,
              "areas_for_improvement": improvements,
              "error_categories": errorCategories,
              "recommendation": recommendation,
              "feedback_tone": analyticalTone,
              "grade_report": {
                "summary": summary,
                "detected_language": detectedLanguage,
                "strengths": strengths,
                "improvements": improvements,
                "plagiarism_matches": matches,
                "error_categories": errorCategories,
                "recommendation": recommendation,
                "feedback_tone": analyticalTone,
              },
              "status": "Ready for Review",
            });
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Grading completed! Plagiarism: $plagiarismScore%",
                style: TextStyle(
                  color: plagiarismScore > 30 ? Colors.red : Colors.green,
                ),
              ),
            ),
          );

          // 4. Reset controls
          _refController.clear();
          _studentController.clear();
          setState(() {
            currentFileName = "Manual Entry";
          });
        } else {
          throw Exception("Failed to save submission");
        }
      } else {
        throw Exception("Server returned status code ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isAnalyzing = false);
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
  // void _showGradingReview(Map<String, dynamic> res) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => Dialog(
  //       insetPadding: const EdgeInsets.all(16),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  //       child: GradingReviewDialog(
  //         submission: {
  //           'student_name': res['title'],
  //           'ai_grade':     res['grade'],
  //           'grade_report': {
  //             'summary':               res['summary'],
  //             'strengths':             res['strengths'],
  //             'areas_for_improvement': res['areas_for_improvement'],
  //             'error_categories':      res['error_categories'],
  //             'recommendation':        res['recommendation'],
  //             'feedback_tone':         res['feedback_tone'],
  //           },
  //           'essay_content':    '',
  //           'plagiarism_score': 0,
  //         },
  //         onFinalize: (grade) async => Navigator.pop(context),
  //       ),
  //     ),
  //   );
  // }
  void _showGradingReview(Map<String, dynamic> res) {
    // Normalize the input data so it fits the schema expected by GradingReviewDialog
    final Map<String, dynamic> normalizedSubmission = {
      'id':               res['id'], // Crucial for backend targeting
      'student_name':     res['student_name'] ?? res['title'] ?? 'Student',
      'ai_grade':         res['ai_grade'] ?? res['grade'] ?? 0,
      'grade':            res['grade'] ?? res['ai_grade'] ?? 0,
      'essay_content':    res['essay_content'] ?? '',
      'plagiarism_score': res['plagiarism_score'] ?? res['plagiarism'] ?? 0,
      'status':           res['status'] ?? 'ready',
      'grade_report': res['grade_report'] ?? {
        'summary':               res['summary'] ?? "Analysis complete.",
        'strengths':             res['strengths'] ?? [],
        'areas_for_improvement': res['areas_for_improvement'] ?? res['improvements'] ?? [],
        'error_categories':      res['error_categories'] ?? {},
        'recommendation':        res['recommendation'] ?? "",
        'feedback_tone':         res['feedback_tone'] ?? "formal",
      },
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GradingReviewDialog(
        submission: normalizedSubmission,
        onFinalize: (finalGrade) async {
          try {
            // 1. Update the grade on your backend service
            final response = await http.put(
              Uri.parse('http://127.0.0.1:8000/api/submissions/${normalizedSubmission['id']}'),
              headers: {"Content-Type": "application/json"},
              body: json.encode({
                "ai_grade": finalGrade.toInt(), // Cast to Int if your DB expects integers
                "status": "graded"
              }),
            );

            if (response.statusCode == 200) {
              // 2. Reactively find and update the element in your local UI state list
              setState(() {
                // Target by unique database record identifier
                final index = resultsList.indexWhere((item) => item['id'] == normalizedSubmission['id']);
                if (index != -1) {
                  resultsList[index]['ai_grade'] = finalGrade;
                  resultsList[index]['grade'] = finalGrade;
                  resultsList[index]['status'] = "Finalized";
                }
              });

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Grade finalized: ${finalGrade.toStringAsFixed(0)}%"),
                    backgroundColor: const Color(0xFF10B981), // matching standard green
                  ),
                );
              }
            } else {
              throw Exception("Server returned code ${response.statusCode}");
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error finalizing grade: $e")),
              );
            }
          }

          // Close the modal sheet panel
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Container(
  //     decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bgGradient)),
  //     child: SingleChildScrollView(
  //       padding: const EdgeInsets.symmetric(horizontal: 20),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           const SizedBox(height: 16),
  //           _buildSectionHeader("1. Reference & Rubric"),
  //           _buildInputCard(
  //             child: Column(
  //               children: [
  //                 Row(children: [_modeChip("Model Answer", 'MODEL'), const SizedBox(width: 10), _modeChip("Rubric", 'RUBRIC')]),
  //                 const SizedBox(height: 15),
  //                 _buildTextField(_refController, "Paste reference here..."),
  //                 const SizedBox(height: 12),
  //                 _buildUploadArea("Upload Reference", () => _pickFile(_refController)),
  //               ],
  //             ),
  //           ),
  //           const SizedBox(height: 25),
  //           _buildSectionHeader("2. Student Submission"),
  //           _buildInputCard(
  //             child: Column(
  //               children: [
  //                 _buildTextField(_studentController, "Paste student work...", onChanged: (val) {
  //                   if (val.isNotEmpty && currentFileName != "Manual Entry") setState(() => currentFileName = "Manual Entry");
  //                 }),
  //                 const SizedBox(height: 12),
  //                 _buildUploadArea("Browse Student File", () => _pickFile(_studentController)),
  //                 const SizedBox(height: 16),
  //                 _buildToneSelector(),
  //                 const SizedBox(height: 12),
  //                 _buildGradientButton(),
  //               ],
  //             ),
  //           ),
  //           const SizedBox(height: 35),
  //           Text("Grading Results", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
  //           const SizedBox(height: 15),
  //           if (resultsList.isEmpty) _buildEmptyState() else ...resultsList.map((res) => _buildResultTile(res)).toList(),
  //           const SizedBox(height: 40),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: bgGradient
          ),
        ),
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF9333EA)))
                  : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Model Answer / Rubric Section
                        Expanded(
                          child: _buildInputCard(
                            title: "Model Answer / Rubric",
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  _modeChip("Model Answer", 'MODEL'),
                                  const SizedBox(width: 10),
                                  _modeChip("Rubric", 'RUBRIC')
                                ]),
                                const SizedBox(height: 15),
                                _buildTextField(_refController, "Paste reference here..."),
                                const SizedBox(height: 12),
                                _buildUploadArea("Upload Reference", () => _pickFile(_refController)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 2. Student Submission Section
                        Expanded(
                          child: _buildInputCard(
                            title: "Student Submission",
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(_studentController, "Paste student work...", onChanged: (val) {
                                  if (val.isNotEmpty && currentFileName != "Manual Entry") {
                                    setState(() => currentFileName = "Manual Entry");
                                  }
                                }),
                                const SizedBox(height: 12),
                                _buildUploadArea("Browse Student File", () => _pickFile(_studentController)),
                                const SizedBox(height: 16),
                                _buildToneSelector(), // Integrated Feedback Tone Selector here
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    _buildGradientButton(),

                    const SizedBox(height: 35),

                    _buildSubmissionsHeader(),
                    const SizedBox(height: 15),

                    // Results Stream List View
                    if (resultsList.isEmpty)
                      _buildEmptyState()
                    else
                      ...resultsList.map((res) => _buildSubmissionCard(res)).toList(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Student Submissions", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
        Text("${resultsList.length} total", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      ],
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> res) {
    double score = (res['grade'] as num).toDouble();
    double plagiarism = (res['plagiarism'] as num).toDouble();

    Color plagiarismColor;
    if (plagiarism < 10) {
      plagiarismColor = Colors.green.shade700;
    } else if (plagiarism < 30) {
      plagiarismColor = Colors.orange.shade700;
    } else {
      plagiarismColor = Colors.red.shade700;
    }
    String status = res['status'] ?? "Ready for Review";
    bool isFinalized = status == "Finalized" || status == "graded";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4)
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  res['title'] ?? res['student_name'] ?? 'Manual Entry',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  "${res['date'] ?? 'Just now'}",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFinalized ? "Finalized" : "Ready for Review",
                        style: TextStyle(
                          color: isFinalized ? Colors.purple.shade700 : Colors.green.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade100),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isFinalized ? Colors.purple.withOpacity(0.05) : primaryPurple.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AI Grade",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              "${score.toInt()}%",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: isFinalized ? Colors.purple.shade700 : primaryPurple,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: score >= 50 ? Colors.green.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isFinalized ? "✓ Finalized" : (score >= 50 ? "✓ Pass" : "⚠️ Needs Work"),
                                style: TextStyle(
                                  color: isFinalized ? Colors.purple.shade700 : (score >= 50 ? Colors.green.shade700 : Colors.orange.shade700),
                                  fontSize: 10,
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

                const SizedBox(width: 12),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: plagiarism < 10 ? Colors.green.shade50 : (plagiarism < 30 ? Colors.orange.shade50 : Colors.red.shade50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Plagiarism",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              "${plagiarism.toInt()}%",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: plagiarismColor,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              plagiarism < 10 ? Icons.check_circle : Icons.warning,
                              color: plagiarismColor,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            InkWell(
              onTap: isFinalized ? null : () => _showGradingReview(res),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isFinalized
                      ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
                      : LinearGradient(colors: [primaryPurple, primaryPurple.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isFinalized ? null : [
                    BoxShadow(color: primaryPurple.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isFinalized ? "✓ Finalized" : "📄 Review & Finalize",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
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

  Widget _buildAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Spacer(),
            Text("AI Grading System", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
            const Spacer(),
            const Icon(Icons.auto_awesome, color: Color(0xFF9333EA)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black45, letterSpacing: 1.1
          )),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {ValueChanged<String>? onChanged}) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: 3,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildUploadArea(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryPurple.withOpacity(0.2), width: 1.5)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: primaryPurple, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: primaryPurple, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientButton() {
    return InkWell(
      onTap: isAnalyzing ? null : _handleGrading,
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: actionGradient),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: actionGradient[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
        ),
        child: Center(
          child: isAnalyzing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Run AI Grading and Analysis", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ),
      ),
    );
  }

  Widget _modeChip(String label, String mode) {
    bool isSelected = selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => selectedMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: isSelected ? primaryPurple : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isSelected ? primaryPurple : Colors.grey.shade200)
        ),
        child: Text(label, style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w700,
            fontSize: 12
        )),
      ),
    );
  }

  Widget _buildToneSelector() {
    const tones = [
      {'value': 'formal',      'label': 'Formal',      'icon': Icons.school,                  'color': Color(0xFF3B82F6)},
      {'value': 'encouraging', 'label': 'Encouraging',  'icon': Icons.sentiment_satisfied_alt,   'color': Color(0xFF10B981)},
      {'value': 'strict',      'label': 'Strict',       'icon': Icons.gavel,                     'color': Color(0xFFEF4444)},
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
            const SizedBox(width: 6),
            Text('(from Settings)', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.analytics_outlined, size: 40, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            Text("No submissions yet", style: TextStyle(color: Colors.grey.shade300)),
          ],
        ),
      ),
    );
  }
}