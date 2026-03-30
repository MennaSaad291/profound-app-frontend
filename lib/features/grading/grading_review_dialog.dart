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
    final report = widget.submission['grade_report'] ?? {};
    final plagiarism = widget.submission['plagiarism_score'] ?? 0;
    final scores = report['criteria_scores'] ?? {};

    final List<Map<String, dynamic>> dynamicRubric = [
      {
        'name': 'Content & Understanding',
        'aiScore': scores['content'] ?? 0,
        'maxScore': 25
      },
      {
        'name': 'Structure & Organization',
        'aiScore': scores['structure'] ?? 0,
        'maxScore': 25
      },
      {
        'name': 'Technical Accuracy',
        'aiScore': scores['technical'] ?? 0,
        'maxScore': 25
      },
      {
        'name': 'Writing Quality',
        'aiScore': scores['writing'] ?? 0,
        'maxScore': 25
      },
    ];

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF7E22CE), Color(0xFF9333EA)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Review Submission",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(widget.submission['student_name'] ?? "",
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
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(Icons.edit, "Student Submission"),
                    _buildContentBox(widget.submission['essay_content'] ?? "No content available."),

                    const SizedBox(height: 20),
                    _buildSectionTitle(Icons.smart_toy, "AI Grade Breakdown", color: Colors.purple),
                    _buildRubricList(dynamicRubric),

                    const SizedBox(height: 20),
                    _buildSectionTitle(Icons.feedback, "AI-Generated Feedback", color: Colors.purple),
                    _buildFeedbackBox(report['summary'] ?? "Analysis complete."),

                    const SizedBox(height: 20),
                    if (plagiarism > 0) _buildPlagiarismAlert(plagiarism),

                    const SizedBox(height: 20),
                    _buildSectionTitle(Icons.edit_note, "Manual Grade Override"),
                    _buildGradeOverrideInput(),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9333EA),
                          foregroundColor: Colors.white
                      ),
                      onPressed: () {
                        double? val = double.tryParse(_gradeController.text);
                        if (val != null) widget.onFinalize(val);
                      },
                      child: const Text("Finalize Grade"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, {Color color = Colors.grey}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildContentBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8)
      ),
      child: Text(text, style: TextStyle(color: Colors.grey.shade800)),
    );
  }

  Widget _buildRubricList(List<Map<String, dynamic>> criteria) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: criteria.map((c) {
          double percent = (c['aiScore'] / c['maxScore']).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c['name']),
                    Text("${c['aiScore']}/${c['maxScore']}",
                        style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                    value: percent,
                    backgroundColor: Colors.purple.shade100,
                    color: Colors.purple
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeedbackBox(String feedback) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade100),
          borderRadius: BorderRadius.circular(12)
      ),
      child: Text(feedback),
    );
  }

  Widget _buildPlagiarismAlert(int score) {
    Color color = score < 10 ? Colors.amber : Colors.red;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12)
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text("$score% Plagiarism detected. Manual review suggested.")),
        ],
      ),
    );
  }

  Widget _buildGradeOverrideInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Text("Final Grade: "),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _gradeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(suffixText: "%", isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}