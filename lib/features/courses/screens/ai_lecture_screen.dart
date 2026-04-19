import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_saver/file_saver.dart';

const String _base = 'http://127.0.0.1:8000';
const int _kMaxSlides = 60;
const int _kMinSlides = 3;

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class AILectureScreen extends StatefulWidget {
  const AILectureScreen({super.key});
  @override
  State<AILectureScreen> createState() => _AILectureScreenState();
}

class _AILectureScreenState extends State<AILectureScreen> {
  // ── Controllers ─────────────────────────────────────────────────
  final _topicController        = TextEditingController();
  final _instructionsController = TextEditingController();
  final _sourcesController      = TextEditingController();
  final _pageCountController    = TextEditingController(text: '10');
  final PageController _pageController = PageController();

  // ── Settings ─────────────────────────────────────────────────────
  String _selectedLevel = 'Undergraduate (Introductory)';
  String _selectedTheme = 'Modern Minimalist';
  bool   _includeMedia  = false;

  // ── State ─────────────────────────────────────────────────────────
  bool _isGenerating = false;
  bool _isExporting  = false;
  bool _showSettings = true;
  bool _showNotes    = true;

  Map<String, dynamic>? _presentationData;
  int _currentSlide = 0;
  final Set<int> _regeneratingSlides = {};

  // ── Dropdowns ─────────────────────────────────────────────────────
  final List<String> _levels = [
    'Undergraduate (Introductory)',
    'Undergraduate (Advanced)',
    'Graduate / Master',
    'PhD Seminar',
  ];
  final List<String> _themes = [
    'Modern Minimalist',
    'Dark Mode Tech',
    'Classic Academic',
    'Vibrant Creative',
  ];

  @override
  void dispose() {
    _topicController.dispose();
    _instructionsController.dispose();
    _sourcesController.dispose();
    _pageCountController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Theme colours ─────────────────────────────────────────────────
  Color get _accent {
    switch (_selectedTheme) {
      case 'Dark Mode Tech':   return const Color(0xFF38BDF8);
      case 'Classic Academic': return const Color(0xFF800000);
      case 'Vibrant Creative': return const Color(0xFFF97316);
      default:                 return const Color(0xFF4F46E5);
    }
  }
  Color get _slideBg {
    switch (_selectedTheme) {
      case 'Dark Mode Tech':   return const Color(0xFF0F172A);
      case 'Classic Academic': return const Color(0xFFFDFBF7);
      case 'Vibrant Creative': return const Color(0xFFFFF7ED);
      default:                 return Colors.white;
    }
  }
  Color get _textColor   => _selectedTheme == 'Dark Mode Tech' ? Colors.white           : const Color(0xFF1F2937);
  Color get _mutedColor  => _selectedTheme == 'Dark Mode Tech' ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
  Color get _detailColor => _selectedTheme == 'Dark Mode Tech' ? const Color(0xFFCBD5E1) : const Color(0xFF374151);

  // ─────────────────────────────────────────────────────────────────
  // API: generate
  // ─────────────────────────────────────────────────────────────────

  Future<void> _generateLecture() async {
    if (_topicController.text.isEmpty) {
      _snack('Please enter a lecture topic', isError: true);
      return;
    }
    final raw = int.tryParse(_pageCountController.text) ?? 10;
    if (raw < _kMinSlides || raw > _kMaxSlides) {
      _snack('Slide count must be between $_kMinSlides and $_kMaxSlides', isError: true);
      return;
    }

    setState(() {
      _isGenerating = true;
      _presentationData = null;
      _currentSlide = 0;
      _showSettings = false;
    });

    try {
      final instructions = _instructionsController.text.trim();
      final sources      = _sourcesController.text.trim();

      final combined = [
        if (instructions.isNotEmpty) instructions,
        if (sources.isNotEmpty) 'Professor sources: $sources',
        if (instructions.isEmpty && sources.isEmpty)
          'Produce a thorough, student-friendly academic lecture.',
      ].join('. ');

      final res = await http.post(
        Uri.parse('$_base/api/generate-lecture'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic':                   _topicController.text.trim(),
          'course_level':            _selectedLevel,
          'pages_count':             raw,
          'additional_instructions': combined,
          'include_media':           _includeMedia,
          'theme':                   _selectedTheme,
        }),
      ).timeout(const Duration(seconds: 180));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['slides'] is List && (decoded['slides'] as List).isNotEmpty) {
          setState(() => _presentationData = {'slides': decoded['slides']});
        } else {
          _snack('Server returned no slides. Please try again.', isError: true);
          setState(() => _showSettings = true);
        }
      } else {
        _snack('Error: ${_parseError(res.body)}', isError: true);
        setState(() => _showSettings = true);
      }
    } catch (e) {
      _snack('Network error: $e', isError: true);
      setState(() => _showSettings = true);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _regenerateSlide(int index) async {
    final slides = _presentationData?['slides'] as List?;
    if (slides == null) return;
    setState(() => _regeneratingSlides.add(index));
    try {
      final res = await http.post(
        Uri.parse('$_base/api/generate-lecture'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic':                   _topicController.text.trim(),
          'course_level':            _selectedLevel,
          'pages_count':             3,
          'additional_instructions': 'Generate exactly 3 slides. Focus slide 2 on: ${slides[index]['title']}',
          'include_media':           false,
          'theme':                   _selectedTheme,
        }),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final decoded   = jsonDecode(res.body);
        final newSlides = decoded['slides'] as List?;
        if (newSlides != null && newSlides.length >= 2) {
          setState(() {
            final updated = List.from(slides);
            updated[index] = newSlides[1];
            _presentationData = {..._presentationData!, 'slides': updated};
          });
          _snack('Slide regenerated');
        }
      }
    } catch (e) {
      _snack('Regeneration failed: $e', isError: true);
    } finally {
      setState(() => _regeneratingSlides.remove(index));
    }
  }

  Future<void> _exportToPowerPoint() async {
    if (_presentationData == null) return;
    setState(() => _isExporting = true);
    try {
      final res = await http.post(
        Uri.parse('$_base/api/export-pptx'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'slides':       _presentationData!['slides'],
          'theme':        _selectedTheme,
          'course_level': _selectedLevel,
        }),
      ).timeout(const Duration(seconds: 90));

      if (res.statusCode == 200) {
        final clean = _topicController.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final fileName = 'Lecture_$clean';

        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: res.bodyBytes,
          fileExtension: 'pptx',
          mimeType: MimeType.microsoftPresentation,
        );

        _snack('Saved: $fileName.pptx');
      } else {
        _snack('Export error: ${_parseError(res.body)}', isError: true);
      }
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  String _parseError(String body) {
    try { return jsonDecode(body)['detail']?.toString() ?? body; } catch (_) { return body; }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      duration: const Duration(seconds: 4),
    ));
  }

  String _clean(String? t) => (t ?? '').replaceAll('**', '').replaceAll('*', '').trim();

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('AI Lecture Builder', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          if (_presentationData != null) ...[
            IconButton(
              icon: Icon(_showSettings ? Icons.settings : Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => setState(() => _showSettings = !_showSettings),
            ),
            IconButton(
              icon: const Icon(Icons.speaker_notes_outlined),
              tooltip: 'Speaker Notes',
              onPressed: () => setState(() => _showNotes = !_showNotes),
            ),
            IconButton(
              icon: _isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.download_rounded),
              tooltip: 'Export .PPTX',
              onPressed: _isExporting ? null : _exportToPowerPoint,
            ),
          ],
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left panel
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _showSettings ? 360 : 0,
            child: _showSettings
                ? ClipRect(child: SizedBox(width: 360, child: _buildSettingsPanel()))
                : null,
          ),
          // Main area
          Expanded(child: _buildMainArea()),
          // Thumbnail panel
          if (_presentationData != null) _buildThumbnailPanel(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Settings panel
  // ─────────────────────────────────────────────────────────────────

  Widget _buildSettingsPanel() => Container(
    color: Colors.white,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ────────────────────────────────────────────────
        Row(children: [
          Icon(Icons.auto_awesome, color: _accent, size: 20),
          const SizedBox(width: 8),
          Text('Lecture Settings', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 18),

        // ── Topic ─────────────────────────────────────────────────
        _lbl('Topic *'),
        TextField(controller: _topicController, decoration: _dec('e.g., Binary Search Trees')),
        const SizedBox(height: 14),

        // ── Instructions ──────────────────────────────────────────
        _lbl('Professor Instructions'),
        TextField(
          controller: _instructionsController, maxLines: 3,
          decoration: _dec('e.g., Highly detailed with examples. Cover misconceptions.',
              helper: 'AI follows your instructions exactly'),
        ),
        const SizedBox(height: 14),

        // ── Sources ───────────────────────────────────────────────
        _lbl('Your Sources (optional)'),
        TextField(
          controller: _sourcesController, maxLines: 2,
          decoration: _dec('e.g., Tanenbaum Ch.3, MIT 6.034 notes',
              helper: 'AI will reference these in content',
              icon: Icons.library_books_outlined),
        ),
        const SizedBox(height: 14),

        // ── Level ─────────────────────────────────────────────────
        _lbl('Academic Level'),
        DropdownButtonFormField<String>(
          value: _selectedLevel, decoration: _dec(''),
          items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _selectedLevel = v!),
        ),
        const SizedBox(height: 14),

        // ── Slide count + Theme ───────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('Slide Count (3–60)'),
            TextField(
              controller: _pageCountController,
              keyboardType: TextInputType.number,
              decoration: _dec('10', helper: 'Max: 60 slides'),
            ),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('Theme'),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedTheme, decoration: _dec(''),
              items: _themes.map((t) => DropdownMenuItem(
                value: t, 
                child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)
              )).toList(),
              onChanged: (v) => setState(() => _selectedTheme = v!),
            ),
          ])),
        ]),
        const SizedBox(height: 16),

        // ── Include Media toggle ──────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent.withOpacity(0.2)),
          ),
          child: SwitchListTile(
            title: const Text('Include Media Resources Slide', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Adds curated academic links after the lecture', style: TextStyle(fontSize: 11)),
            value: _includeMedia, activeColor: _accent,
            onChanged: (v) => setState(() => _includeMedia = v),
          ),
        ),
        const SizedBox(height: 24),

        // ── Generate button ───────────────────────────────────────
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isGenerating ? null : _generateLecture,
            icon: _isGenerating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(
              _isGenerating ? 'Generating...' : 'Generate Lecture',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        if (_presentationData != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green.shade600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isExporting ? null : _exportToPowerPoint,
              icon: Icon(Icons.download, color: Colors.green.shade700),
              label: Text('Export as .PPTX', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ]),
    ),
  );

  // ─────────────────────────────────────────────────────────────────
  // Main area
  // ─────────────────────────────────────────────────────────────────

  Widget _buildMainArea() {
    if (_isGenerating) return _buildLoading();
    if (_presentationData == null) return _buildEmpty();
    return _buildSlideViewer();
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.slideshow_rounded, size: 80, color: Colors.grey.shade300),
    const SizedBox(height: 20),
    Text('Your lecture will appear here', style: GoogleFonts.inter(fontSize: 18, color: Colors.grey.shade500)),
    const SizedBox(height: 8),
    Text('Fill in the settings and click Generate', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400)),
    if (!_showSettings) ...[
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => setState(() => _showSettings = true),
        icon: const Icon(Icons.settings),
        label: const Text('Open Settings'),
        style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
      ),
    ],
  ]));

  Widget _buildLoading() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    CircularProgressIndicator(color: _accent),
    const SizedBox(height: 24),
    Text('Generating your lecture...', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _accent)),
    const SizedBox(height: 8),
    Text('Building rich content with explanations per point', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
    const SizedBox(height: 4),
    Text('This may take 20–60 seconds depending on slide count', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
  ]));

  // ─────────────────────────────────────────────────────────────────
  // Slide viewer
  // ─────────────────────────────────────────────────────────────────

  Widget _buildSlideViewer() {
    final slides = _presentationData!['slides'] as List;
    final slide  = slides[_currentSlide] as Map<String, dynamic>;

    return Column(
      children: [
        _buildNavBar(slides.length),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentSlide = i),
              itemCount: slides.length,
              itemBuilder: (ctx, i) => _buildSlideCard(slides[i] as Map<String, dynamic>, i),
            ),
          ),
        ),
        if (_showNotes) _buildSpeakerNotes(slide),
      ],
    );
  }

  Widget _buildNavBar(int total) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Text('${_currentSlide + 1} / $total',
            style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      const Spacer(),
      IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, color: _currentSlide > 0 ? _accent : Colors.grey.shade300, size: 20),
        onPressed: _currentSlide > 0
            ? () => _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut)
            : null,
      ),
      IconButton(
        icon: Icon(Icons.arrow_forward_ios_rounded, color: _currentSlide < total - 1 ? _accent : Colors.grey.shade300, size: 20),
        onPressed: _currentSlide < total - 1
            ? () => _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut)
            : null,
      ),
    ]),
  );

  // ─────────────────────────────────────────────────────────────────
  // Slide card
  // ─────────────────────────────────────────────────────────────────

  Widget _buildSlideCard(Map<String, dynamic> slide, int index) {
    final points   = (slide['points']  as List?) ?? [];
    final example  = _clean(slide['example']);
    final imgSug   = slide['image_suggestion'];
    final isRegen  = _regeneratingSlides.contains(index);
    final isRef    = _isRefSlide(slide);

    return Container(
      decoration: BoxDecoration(
        color: _slideBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withOpacity(0.2), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Stack(children: [
        // Left accent bar
        Positioned(left: 0, top: 0, bottom: 0, child: Container(
          width: 5,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
          ),
        )),

        if (isRegen)
          const Center(child: CircularProgressIndicator()),

        if (!isRegen) SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Title + regenerate ──────────────────────────────────
            Row(children: [
              Expanded(child: Text(_clean(slide['title']),
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _textColor))),
              IconButton(
                icon: Icon(Icons.refresh, color: _accent, size: 18),
                tooltip: 'Regenerate this slide',
                onPressed: () => _regenerateSlide(index),
              ),
            ]),

            // Accent underline
            Container(width: 60, height: 3, margin: const EdgeInsets.only(top: 4, bottom: 16),
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),

            // ── Points ─────────────────────────────────────────────
            if (!isRef)
              ...points.map((p) {
                final headline = _clean((p as Map)['headline']?.toString());
                final detail   = _clean(p['detail']?.toString());
                return _buildPoint(headline, detail);
              }),

            // ── Reference / resource slide ──────────────────────────
            if (isRef)
              ...points.map((p) {
                final headline = _clean((p as Map)['headline']?.toString());
                final detail   = _clean(p['detail']?.toString());
                final isUrl    = detail.startsWith('http');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: isUrl ? () => launchUrl(Uri.parse(detail), mode: LaunchMode.externalApplication) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _accent.withOpacity(0.25)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(
                          isUrl ? Icons.open_in_new : Icons.menu_book_rounded,
                          color: _accent, size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(headline, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _accent)),
                          const SizedBox(height: 2),
                          Text(detail,
                            style: TextStyle(
                              fontSize: 12, color: isUrl ? _accent : _detailColor,
                              fontStyle: isUrl ? FontStyle.normal : FontStyle.italic,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ])),
                      ]),
                    ),
                  ),
                );
              }),

            // ── Example ────────────────────────────────────────────
            if (example.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedTheme == 'Dark Mode Tech' ? const Color(0xFF0C2A2A) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.35)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.lightbulb_outline, size: 14, color: Color(0xFF059669)),
                    SizedBox(width: 6),
                    Text('EXAMPLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669), letterSpacing: 1.0)),
                  ]),
                  const SizedBox(height: 8),
                  SelectableText(example, style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF065F46))),
                ]),
              ),
            ],

            // ── Image suggestion ────────────────────────────────────
            if (imgSug != null && imgSug.toString().isNotEmpty && imgSug.toString().toLowerCase() != 'null') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accent.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.image_outlined, size: 14, color: _accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Suggested visual: ${imgSug.toString()}',
                    style: TextStyle(fontSize: 11, color: _accent, fontStyle: FontStyle.italic))),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildPoint(String headline, String detail) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 8, height: 8,
          margin: const EdgeInsets.only(top: 6, right: 10),
          decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
        ),
        Expanded(child: Text(headline,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _textColor, height: 1.3))),
      ]),
      if (detail.isNotEmpty) Padding(
        padding: const EdgeInsets.only(left: 18, top: 4),
        child: SelectableText(detail,
          style: GoogleFonts.inter(fontSize: 13, height: 1.65, color: _detailColor, fontWeight: FontWeight.w400)),
      ),
    ]),
  );

  Widget _buildSpeakerNotes(Map<String, dynamic> slide) {
    final notes = _clean(slide['speaker_notes']);
    if (notes.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.speaker_notes_outlined, size: 16, color: _accent),
          const SizedBox(width: 8),
          Text('Speaker Notes', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _accent)),
        ]),
        const SizedBox(height: 8),
        Text(notes, style: GoogleFonts.inter(fontSize: 12, height: 1.6, color: _mutedColor)),
      ]),
    );
  }

  bool _isRefSlide(Map<String, dynamic> slide) {
    final t = (slide['title'] ?? '').toString().toLowerCase();
    return t.contains('reference') || t.contains('further') || t.contains('resource');
  }

  // ─────────────────────────────────────────────────────────────────
  // Thumbnail panel
  // ─────────────────────────────────────────────────────────────────

  Widget _buildThumbnailPanel() {
    final slides = (_presentationData!['slides'] as List);
    return Container(
      width: 160,
      color: const Color(0xFFF8FAFC),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(12),
            child: Text('Slides', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey))),
        Expanded(child: ListView.builder(
          itemCount: slides.length,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemBuilder: (ctx, i) {
            final s = slides[i] as Map<String, dynamic>;
            final isActive = i == _currentSlide;
            return GestureDetector(
              onTap: () { _pageController.jumpToPage(i); setState(() => _currentSlide = i); },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive ? _accent : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isActive ? _accent : Colors.grey.shade200),
                  boxShadow: isActive ? [BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 8)] : [],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i + 1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isActive ? Colors.white70 : Colors.grey)),
                  const SizedBox(height: 3),
                  Text(_clean(s['title']), maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? Colors.white : Colors.black87)),
                ]),
              ),
            );
          },
        )),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF374151))),
  );

  InputDecoration _dec(String hint, {String? helper, IconData? icon, String? hint2}) => InputDecoration(
    hintText: hint2 ?? hint,
    helperText: helper,
    helperMaxLines: 2,
    helperStyle: const TextStyle(fontSize: 10),
    prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF9CA3AF)) : null,
    filled: true, fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _accent, width: 1.5)),
    isDense: true,
  );
}