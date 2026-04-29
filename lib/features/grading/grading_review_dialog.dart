import 'package:flutter/material.dart';

class GradingReviewDialog extends StatefulWidget {
  final Map<String, dynamic> submission;
  final Function(double) onFinalize;

  const GradingReviewDialog({
    super.key,
    required this.submission,
    required this.onFinalize,
  });

  @override
  State<GradingReviewDialog> createState() => _GradingReviewDialogState();
}

class _GradingReviewDialogState extends State<GradingReviewDialog> {
  late TextEditingController _gradeController;

  @override
  void initState() {
    super.initState();
    _gradeController = TextEditingController(
      text: widget.submission['ai_grade']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _gradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access nested report data from your backend JSON
    final report = widget.submission['grade_report'] ?? {};
    final String lang = report['detected_language'] ?? "Unknown";
    final plagiarism = widget.submission['plagiarism_score'] ?? 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(Icons.description, "Student Submission"),
                  // This displays the essay_content from your SubmissionDB
                  _buildContentBox(widget.submission['essay_content'] ?? "No content found in database."),

                  const SizedBox(height: 24),

                  _buildSectionTitle(Icons.feedback, "AI Feedback ($lang)", color: Colors.purple),
                  _buildFeedbackBox(report['summary'] ?? "Analysis complete."),

                  if (plagiarism > 0) ...[
                    const SizedBox(height: 24),
                    _buildPlagiarismAlert(plagiarism),
                  ],

                  const SizedBox(height: 24),

                  _buildSectionTitle(Icons.edit_note, "Final Adjustment", color: Colors.orange),
                  _buildGradeOverrideInput(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF9333EA), Color(0xFF7E22CE)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Grading Review",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(widget.submission['student_name'] ?? "Student",
                    style: TextStyle(color: Colors.purple.shade100, fontSize: 14)),
              ],
            ),
          ),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white)
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, {Color color = Colors.blueGrey}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildContentBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(text, style: const TextStyle(height: 1.5, color: Colors.black87)),
    );
  }

  Widget _buildFeedbackBox(String feedback) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Text(feedback, style: const TextStyle(height: 1.5, color: Colors.blueAccent)),
    );
  }

  Widget _buildGradeOverrideInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text("Final Score Adjustment",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _gradeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              decoration: const InputDecoration(
                suffixText: "%",
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text("Cancel")
          )),
          const SizedBox(width: 16),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9333EA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            onPressed: () {
              double? val = double.tryParse(_gradeController.text);
              if (val != null) widget.onFinalize(val);
            },
            child: const Text("Finalize Grade", style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ],
      ),
    );
  }

  Widget _buildPlagiarismAlert(int score) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [const Icon(Icons.warning, color: Colors.red), const SizedBox(width: 12), Text("$score% Plagiarism detected.")]),
    );
  }
}