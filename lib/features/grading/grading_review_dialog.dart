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
  bool _isSaving = false;

  // Theme configuration fallbacks used across builders
  static const Color _blue = Color(0xFF1D4ED8);
  static const Color _green = Color(0xFF10B981);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _purple = Color(0xFF9333EA);
  static const Color _red = Color(0xFFEF4444);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _gradeController = TextEditingController(
      text: widget.submission['manual_grade']?.toString() ??
          widget.submission['ai_grade']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _gradeController.dispose();
    super.dispose();
  }

  // Helper utility extractors
  String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  IconData _toneIcon(String tone) {
    switch (tone.toLowerCase()) {
      case 'encouraging': return Icons.sentiment_satisfied_alt;
      case 'critical': return Icons.gavel;
      default: return Icons.assignment_turned_in_outlined;
    }
  }

  Color _scoreColor(int score) {
    if (score >= 85) return _green;
    if (score >= 60) return _amber;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    final report       = widget.submission['grade_report'] ?? {};
    final score        = (widget.submission['ai_grade'] as num?)?.toInt() ?? 0;
    final plagiarism   = widget.submission['plagiarism_score'] ?? 0;
    final tone         = _nonEmpty(report['feedback_tone']) ?? 'formal';
    final lang         = report['detected_language'] ?? "Unknown";

    final summary = _nonEmpty(report['summary']) ??
        _nonEmpty(widget.submission['essay_content']?.toString().substring(0, 80)) ??
        'No summary available.';

    final strengths    = _toStringList(report['strengths']);
    final improvements = _toStringList(report['areas_for_improvement'] ?? report['improvements']);
    final errors         = report['error_categories'];
    final recommendation = _nonEmpty(report['recommendation']);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(score, tone),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScoreRow(score, plagiarism),
                  const SizedBox(height: 20),

                  // ---------- Overall AI Assessment ----------
                  _buildSection(
                    icon: Icons.summarize_outlined,
                    label: 'Overall Assessment ($lang)',
                    color: _blue,
                    child: _buildTextBox(summary, bgColor: const Color(0xFFEFF6FF), textColor: const Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(height: 16),

                  // ---------- Strengths ----------
                  if (strengths.isNotEmpty) ...[
                    _buildSection(
                      icon: Icons.check_circle_outline,
                      label: 'Strengths',
                      color: _green,
                      child: _buildBulletList(strengths, color: _green, bgColor: const Color(0xFFECFDF5)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ---------- Areas for Improvement ----------
                  if (improvements.isNotEmpty) ...[
                    _buildSection(
                      icon: Icons.trending_up,
                      label: 'Areas for Improvement',
                      color: _amber,
                      child: _buildBulletList(improvements, color: _amber, bgColor: const Color(0xFFFFFBEB)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ---------- Error Breakdown Categories ----------
                  if (errors is Map && errors.isNotEmpty) ...[
                    _buildErrorCategories(errors),
                    const SizedBox(height: 16),
                  ],

                  // ---------- Actionable Recommendations ----------
                  if (recommendation != null) ...[
                    _buildSection(
                      icon: Icons.lightbulb_outline,
                      label: 'Recommended Next Step',
                      color: _purple,
                      child: _buildTextBox(recommendation, bgColor: const Color(0xFFF5F3FF), textColor: const Color(0xFF6B21A8)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ---------- Original Student Essay Content Box ----------
                  _buildSection(
                    icon: Icons.description_outlined,
                    label: 'Student Submission',
                    color: Colors.blueGrey,
                    child: _buildTextBox(
                      widget.submission['essay_content'] ?? 'No content found in database.',
                      bgColor: _surface,
                      textColor: Colors.black87,
                      maxLines: 6,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---------- Plagiarism Segment / Alerts ----------
                  _buildSection(
                    icon: Icons.copy,
                    label: "Plagiarism Check",
                    color: Colors.red,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        _buildPlagiarismSection(widget.submission),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---------- Final Grade Adjustment Input Overrides ----------
                  _buildSection(
                    icon: Icons.edit_note,
                    label: 'Final Grade Adjustment',
                    color: Colors.orange,
                    child: _buildGradeOverride(),
                  ),
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

  // ── Widget Builders ───────────────────────────────────────────────────

  Widget _buildHeader(int score, String tone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF9333EA), Color(0xFF7E22CE)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Icon(_toneIcon(tone), color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Grading Review',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  widget.submission['student_name'] ?? 'Student',
                  style: TextStyle(color: Colors.purple.shade100, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tone.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(int score, dynamic plagiarism) {
    final int? manualGrade = (widget.submission['manual_grade'] as num?)?.toInt();
    final bool overridden = manualGrade != null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'AI Score',
                value: '$score%',
                color: _scoreColor(score),
                icon: Icons.auto_awesome,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                label: 'Plagiarism',
                value: '$plagiarism%',
                color: (plagiarism as num) > 10 ? _red : _green,
                icon: Icons.shield_outlined,
              ),
            ),
          ],
        ),
        if (overridden) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, color: Colors.orange, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Professor Override',
                        style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'AI: $score%  →  Final: $manualGrade%',
                        style: const TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$manualGrade%',
                  style: const TextStyle(color: Colors.orange, fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
              Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String label,
    required Color color,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTextBox(String text, {
    required Color bgColor,
    required Color textColor,
    int maxLines = 20,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.15)),
      ),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: textColor, height: 1.5, fontSize: 13),
      ),
    );
  }

  Widget _buildBulletList(List<String> items, {required Color color, required Color bgColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.circle, size: 6, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(item, style: TextStyle(color: color.withOpacity(0.85), fontSize: 13, height: 1.4))),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildErrorCategories(Map errors) {
    final categories = {
      'conceptual':   {'label': 'Conceptual',   'icon': Icons.psychology_outlined,  'color': const Color(0xFF8B5CF6)},
      'structural':   {'label': 'Structural',   'icon': Icons.account_tree_outlined, 'color': const Color(0xFF0EA5E9)},
      'language':      {'label': 'Language',      'icon': Icons.translate,             'color': const Color(0xFFF97316)},
      'completeness': {'label': 'Completeness', 'icon': Icons.playlist_add_check,    'color': const Color(0xFF10B981)},
    };

    final tiles = categories.entries
        .where((e) => _nonEmpty(errors[e.key]) != null)
        .map((e) {
      final meta  = e.value;
      final note  = _nonEmpty(errors[e.key])!;
      final color = meta['color'] as Color;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(meta['icon'] as IconData, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta['label'] as String, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(note, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();

    if (tiles.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      icon: Icons.category_outlined,
      label: 'Error Categories',
      color: const Color(0xFF64748B),
      child: Column(children: tiles),
    );
  }
  Widget _buildPlagiarismSection(Map<String, dynamic> submission) {
    final plagiarismScore = submission['plagiarism_score'] ?? 0;

    // Robust lookups for similar submission matches whether they're in the root or nested inside grade_report
    final dynamic rawMatches = submission['plagiarism_matches'] ??
        submission['matches'] ??
        (submission['grade_report'] != null ? submission['grade_report']['plagiarism_matches'] : null) ??
        [];

    final List<dynamic> matches = rawMatches is List ? rawMatches : [];

    if (plagiarismScore == 0 && matches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 10),
            const Text("No plagiarism detected", style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: plagiarismScore > 30 ? Colors.red.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: plagiarismScore > 30 ? Colors.red.shade200 : Colors.orange.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: plagiarismScore > 30 ? Colors.red.shade700 : Colors.orange.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Plagiarism Score: $plagiarismScore%",
                      style: TextStyle(
                        color: plagiarismScore > 30 ? Colors.red.shade700 : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plagiarismScore > 30
                          ? "High similarity detected. Review submission for potential plagiarism."
                          : "Moderate similarity detected. Review the submission details below.",
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (matches.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
              "Similar Submissions Found:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)
          ),
          const SizedBox(height: 8),
          ...matches.take(3).map((match) {
            final String name = match['student_name'] ?? 'Unknown Student';
            final double similarity = (match['similarity'] ?? 0).toDouble();

            return Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          "Similarity: ${similarity.toStringAsFixed(1)}%",
                          style: TextStyle(color: similarity > 30 ? Colors.red.shade700 : Colors.grey.shade600, fontSize: 11, fontWeight: similarity > 30 ? FontWeight.w600 : FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 12),
                ],
              ),
            );
          }).toList(),
          if (matches.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                "... and ${matches.length - 3} more similar submissions",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ],
    );
  }
  Widget _buildPlagiarismAlert(dynamic score) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$score% similarity detected. Review submission for potential plagiarism.',
              style: TextStyle(color: _red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeOverride() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('Override Final Score', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _gradeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              decoration: const InputDecoration(
                suffixText: '%',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              onPressed: _isSaving
                  ? null
                  : () async {
                final val = double.tryParse(_gradeController.text);
                if (val == null) return;
                setState(() => _isSaving = true);
                await widget.onFinalize(val);
                if (mounted) setState(() => _isSaving = false);
              },
              child: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text('Finalize Grade', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}