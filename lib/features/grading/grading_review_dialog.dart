import 'package:flutter/material.dart';

class GradingReviewDialog extends StatefulWidget {
  final Map<String, dynamic> submission;
  final Future<void> Function(double) onFinalize;

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
  bool _isSaving = false; // tracks finalize-in-progress

  // ── Theme colours ─────────────────────────────────────────────────────
  static const Color _purple      = Color(0xFF9333EA);
  static const Color _green       = Color(0xFF10B981);
  static const Color _amber       = Color(0xFFF59E0B);
  static const Color _red         = Color(0xFFEF4444);
  static const Color _blue        = Color(0xFF3B82F6);
  static const Color _surface     = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    final int? manualGrade =
        (widget.submission['manual_grade'] as num?)?.toInt();
    final int? aiGrade =
        (widget.submission['ai_grade'] as num?)?.toInt();
    _gradeController = TextEditingController(
      text: (manualGrade ?? aiGrade)?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _gradeController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Map<String, dynamic> get _report {
    final r = widget.submission['grade_report'];
    if (r is Map<String, dynamic>) return r;
    return {};
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return (s.isEmpty || s.toLowerCase() == 'null') ? null : s;
  }

  Color _scoreColor(int score) {
    if (score >= 80) return _green;
    if (score >= 60) return _amber;
    return _red;
  }

  IconData _toneIcon(String? tone) {
    switch (tone) {
      case 'encouraging': return Icons.sentiment_satisfied_alt;
      case 'strict':      return Icons.gavel;
      default:            return Icons.school;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final score        = (widget.submission['ai_grade'] as num?)?.toInt() ?? 0;
    final plagiarism   = widget.submission['plagiarism_score'] ?? 0;
    final tone         = _nonEmpty(_report['feedback_tone']) ?? 'formal';
    final summary      = _nonEmpty(_report['summary']) ?? _nonEmpty(widget.submission['essay_content']?.toString().substring(0, 80)) ?? 'No summary available.';
    final strengths    = _toStringList(_report['strengths']);
    final improvements = _toStringList(_report['areas_for_improvement']);
    final errors       = _report['error_categories'];
    final recommendation = _nonEmpty(_report['recommendation']);

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

                  _buildSection(
                    icon: Icons.summarize_outlined,
                    label: 'Overall Assessment',
                    color: _blue,
                    child: _buildTextBox(summary, bgColor: const Color(0xFFEFF6FF), textColor: const Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(height: 16),

                  if (strengths.isNotEmpty) ...[
                    _buildSection(
                      icon: Icons.check_circle_outline,
                      label: 'Strengths',
                      color: _green,
                      child: _buildBulletList(strengths, color: _green, bgColor: const Color(0xFFECFDF5)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (improvements.isNotEmpty) ...[
                    _buildSection(
                      icon: Icons.trending_up,
                      label: 'Areas for Improvement',
                      color: _amber,
                      child: _buildBulletList(improvements, color: _amber, bgColor: const Color(0xFFFFFBEB)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (errors is Map && errors.isNotEmpty)
                    _buildErrorCategories(errors),

                  if (recommendation != null) ...[
                    const SizedBox(height: 16),
                    _buildSection(
                      icon: Icons.lightbulb_outline,
                      label: 'Recommended Next Step',
                      color: _purple,
                      child: _buildTextBox(recommendation, bgColor: const Color(0xFFF5F3FF), textColor: const Color(0xFF6B21A8)),
                    ),
                  ],

                  const SizedBox(height: 16),
                  _buildSection(
                    icon: Icons.description_outlined,
                    label: 'Student Submission',
                    color: Colors.blueGrey,
                    child: _buildTextBox(
                      widget.submission['essay_content'] ?? 'No content stored.',
                      bgColor: _surface,
                      textColor: Colors.black87,
                      maxLines: 6,
                    ),
                  ),

                  if ((plagiarism as num) > 10) ...[
                    const SizedBox(height: 16),
                    _buildPlagiarismAlert(plagiarism),
                  ],

                  const SizedBox(height: 20),
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

  // ── Widget builders ───────────────────────────────────────────────────

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
    final int? manualGrade =
        (widget.submission['manual_grade'] as num?)?.toInt();
    final bool overridden = manualGrade != null;
    final int displayScore = overridden ? manualGrade : score;

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
                        style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'AI: $score%  →  Final: $manualGrade%',
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$manualGrade%',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 22,
                      fontWeight: FontWeight.w900),
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
            Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
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
      'language':     {'label': 'Language',     'icon': Icons.translate,             'color': const Color(0xFFF97316)},
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
                  Text(meta['label'] as String,
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
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
            child: Text('Override Final Score',
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
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Finalize Grade',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
