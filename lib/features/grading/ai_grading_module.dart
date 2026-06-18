import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../grading/grading_review_dialog.dart';
import '../../core/services/grading_settings_service.dart';

class AiGradingModule extends StatefulWidget {
  const AiGradingModule({super.key});

  @override
  State<AiGradingModule> createState() => _AiGradingModuleState();
}

class _AiGradingModuleState extends State<AiGradingModule> {
  // Logic & State
  String selectedMode = 'MODEL';
  bool isAnalyzing = false;
  String currentFileName = "Manual Entry";
  // Tone: starts from the saved setting, can be overridden per-session
  String _sessionTone = GradingSettingsService.instance.feedbackTone;
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _studentController = TextEditingController();
  List<Map<String, dynamic>> resultsList = [];

  // Theme Colors
  final Color primaryPurple = const Color(0xFF9333EA);
  final List<Color> actionGradient = [const Color(0xFF9333EA), const Color(0xFF7E22CE)];
  final List<Color> bgGradient = [const Color(0xFFF5F3FF), Colors.white, const Color(0xFFFFFBEB)];

  // --- FILE EXTRACTION LOGIC ---
  Future<void> _pickFile(TextEditingController controller) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
      withData: true,
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      setState(() {
        // Remove extension for the student name
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

  // --- GRADING LOGIC ---
  Future<void> _handleGrading() async {
    if (_refController.text.isEmpty || _studentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide reference and student content")),
      );
      return;
    }

    setState(() => isAnalyzing = true);

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/analyze-general-submission'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "student_text": _studentController.text,
          "mode": selectedMode,
          "reference_content": _refController.text,
          "feedback_tone": _sessionTone,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          resultsList.insert(0, {
            "title":             currentFileName,
            "grade":             data['score_out_of_100'] ?? 0,
            "summary":           data['summary'] ?? "Analysis complete.",
            "strengths":         data['strengths'] ?? [],
            "areas_for_improvement": data['areas_for_improvement'] ?? [],
            "error_categories":  data['error_categories'] ?? {},
            "recommendation":    data['recommendation'] ?? "",
            "feedback_tone":     data['feedback_tone'] ?? "formal",
            "time":              "Just now",
          });
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isAnalyzing = false);
    }
  }

  // --- REVIEW DIALOG ---
  void _showGradingReview(Map<String, dynamic> res) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: GradingReviewDialog(
          submission: {
            'student_name': res['title'],
            'ai_grade':     res['grade'],
            'grade_report': {
              'summary':               res['summary'],
              'strengths':             res['strengths'],
              'areas_for_improvement': res['areas_for_improvement'],
              'error_categories':      res['error_categories'],
              'recommendation':        res['recommendation'],
              'feedback_tone':         res['feedback_tone'],
            },
            'essay_content':    '',
            'plagiarism_score': 0,
          },
          onFinalize: (grade) => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bgGradient)),
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("1. Reference & Rubric"),
                    _buildInputCard(
                      child: Column(
                        children: [
                          Row(children: [_modeChip("Model Answer", 'MODEL'), const SizedBox(width: 10), _modeChip("Rubric", 'RUBRIC')]),
                          const SizedBox(height: 15),
                          _buildTextField(_refController, "Paste reference here..."),
                          const SizedBox(height: 12),
                          _buildUploadArea("Upload Reference", () => _pickFile(_refController)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    _buildSectionHeader("2. Student Submission"),
                    _buildInputCard(
                      child: Column(
                        children: [
                          _buildTextField(_studentController, "Paste student work...", onChanged: (val) {
                            if (val.isNotEmpty && currentFileName != "Manual Entry") setState(() => currentFileName = "Manual Entry");
                          }),
                          const SizedBox(height: 12),
                          _buildUploadArea("Browse Student File", () => _pickFile(_studentController)),
                          const SizedBox(height: 16),
                          _buildToneSelector(),
                          const SizedBox(height: 12),
                          _buildGradientButton(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 35),
                    Text("Grading Results", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 15),
                    if (resultsList.isEmpty) _buildEmptyState() else ...resultsList.map((res) => _buildResultTile(res)).toList(),
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

  Widget _buildAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
            const Spacer(),
            Text("AI Grading System", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
            const Spacer(),
            const Icon(Icons.auto_awesome, color: Color(0xFF9333EA)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(Map<String, dynamic> res) {
    double score = (res['grade'] as num).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showGradingReview(res),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(width: 55, height: 55, child: CircularProgressIndicator(value: score / 100, backgroundColor: Colors.grey.shade100, color: primaryPurple, strokeWidth: 5)),
                  Text("${score.toInt()}", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, color: primaryPurple)),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(res['title'], style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(res['summary'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black45, letterSpacing: 1.1)));
  }

  Widget _buildInputCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))]),
      child: child,
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryPurple.withOpacity(0.2), width: 1.5)),
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
        height: 55,
        decoration: BoxDecoration(gradient: LinearGradient(colors: actionGradient), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: actionGradient[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Center(
          child: isAnalyzing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("ANALYSE GRADE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
        decoration: BoxDecoration(color: isSelected ? primaryPurple : Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: isSelected ? primaryPurple : Colors.grey.shade200)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }

  Widget _buildToneSelector() {
    const tones = [
      {'value': 'formal',      'label': 'Formal',      'icon': Icons.school,                    'color': Color(0xFF3B82F6)},
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
    return Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(children: [Icon(Icons.analytics_outlined, size: 40, color: Colors.grey.shade200), const SizedBox(height: 10), Text("No data to show", style: TextStyle(color: Colors.grey.shade300))])));
  }
}