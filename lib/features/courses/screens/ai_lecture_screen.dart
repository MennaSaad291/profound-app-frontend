import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_saver/file_saver.dart';

const String _base = 'http://127.0.0.1:8000';
const int _kMaxSlides = 60;
const int _kMinSlides = 3;

// ─────────────────────────────────────────────────────────────────────────────
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
  String _selectedTheme = 'Modern Minimalist';

  // ── State ─────────────────────────────────────────────────────────
  bool _isGenerating = false;
  bool _isExporting  = false;
  bool _showSettings = true;
  bool _showNotes    = true;

  Map<String, dynamic>? _presentationData;
  int _currentSlide = 0;
  final Set<int> _regeneratingSlides = {};

  // ── Uploaded reference material ───────────────────────────────────────────
  PlatformFile? _uploadedMaterial;

  // ── Dropdowns ─────────────────────────────────────────────────────
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

      // If material was uploaded, extract its text via backend and prepend to instructions
      String uploadedContext = '';
      if (_uploadedMaterial != null) {
        try {
          final req = http.MultipartRequest('POST', Uri.parse('$_base/extract-text'));
          req.files.add(http.MultipartFile.fromBytes(
              'file', _uploadedMaterial!.bytes!, filename: _uploadedMaterial!.name));
          final stream = await req.send().timeout(const Duration(seconds: 30));
          final extracted = await http.Response.fromStream(stream);
          if (extracted.statusCode == 200) {
            final text = jsonDecode(extracted.body)['extracted_text'] as String? ?? '';
            if (text.isNotEmpty) {
              // Keep first 1500 chars to avoid bloating the generation prompt
              uploadedContext = 'Base the lecture on this reference material: ${text.substring(0, text.length.clamp(0, 1500))}. ';
            }
          }
        } catch (_) {} // non-fatal — continue without uploaded content
      }

      final combined = [
        if (uploadedContext.isNotEmpty) uploadedContext,
        if (instructions.isNotEmpty) instructions,
        if (sources.isNotEmpty) 'Professor sources: $sources',
        if (uploadedContext.isEmpty && instructions.isEmpty && sources.isEmpty)
          'Produce a thorough, student-friendly academic lecture.',
      ].join(' ');

      final res = await http.post(
        Uri.parse('$_base/api/generate-lecture'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic':                   _topicController.text.trim(),
          'pages_count':             raw,
          'additional_instructions': combined,
          'theme':                   _selectedTheme,
        }),
      ).timeout(const Duration(seconds: 360));

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
          'pages_count':             3,
          'additional_instructions': 'Generate exactly 3 slides. Focus slide 2 on: ${slides[index]['title']}',
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
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── Page title + action bar (replaces removed AppBar actions) ──
          Container(
            color: _accent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text('AI Lecture Builder',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (_presentationData != null) ...[
                  IconButton(
                    icon: Icon(_showSettings ? Icons.settings : Icons.settings_outlined, color: Colors.white),
                    tooltip: 'Settings',
                    onPressed: () => setState(() => _showSettings = !_showSettings),
                  ),
                  IconButton(
                    icon: const Icon(Icons.speaker_notes_outlined, color: Colors.white),
                    tooltip: 'Speaker Notes',
                    onPressed: () => setState(() => _showNotes = !_showNotes),
                  ),
                  IconButton(
                    icon: _isExporting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download_rounded, color: Colors.white),
                    tooltip: 'Export .PPTX',
                    onPressed: _isExporting ? null : _exportToPowerPoint,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _showSettings ? 360 : 0,
            child: _showSettings
                ? ClipRect(child: SizedBox(width: 360, child: _buildSettingsPanel()))
                : null,
          ),
          Expanded(child: _buildMainArea()),
          if (_presentationData != null) _buildThumbnailPanel(),
        ],
            ), 
          ), 
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
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

        // ── Upload reference material ──────────────────────────────
        _lbl('Reference Material (Optional)'),
        GestureDetector(
          onTap: () async {
            final result = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'docx', 'txt'],
              withData: true,
            );
            if (result != null) setState(() => _uploadedMaterial = result.files.first);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _uploadedMaterial != null ? _accent.withOpacity(0.06) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _uploadedMaterial != null ? _accent : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(children: [
              Icon(_uploadedMaterial != null ? Icons.check_circle_outline : Icons.upload_file_outlined,
                  color: _uploadedMaterial != null ? _accent : Colors.grey, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _uploadedMaterial != null
                    ? _uploadedMaterial!.name
                    : 'Upload lecture notes, syllabus or reference (PDF/DOCX/TXT)',
                style: TextStyle(fontSize: 12, color: _uploadedMaterial != null ? _accent : Colors.grey),
                overflow: TextOverflow.ellipsis,
              )),
              if (_uploadedMaterial != null)
                GestureDetector(
                  onTap: () => setState(() => _uploadedMaterial = null),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Text('AI will base the lecture content on your uploaded material',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
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

  Widget _buildLoading() {
    final slideCount = int.tryParse(_pageCountController.text) ?? 10;
    // Outline: ~3s. Batches of 5 in groups of 3 parallel + 3s gap between waves.
    final batches = (slideCount / 5).ceil();
    final waves   = (batches / 3).ceil();
    final estSecs = 3 + (waves * 10);
    final estMin  = estSecs ~/ 60;
    final estRemS = estSecs % 60;
    final estStr  = estMin > 0 ? '~$estMin min ${estRemS}s' : '~${estSecs}s';

    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: _accent),
      const SizedBox(height: 24),
      Text('Generating your lecture...', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _accent)),
      const SizedBox(height: 10),
      Text('Building outline, then generating all slides in parallel', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
      const SizedBox(height: 4),
      Text('Estimated time: $estStr for $slideCount slides', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
      const SizedBox(height: 4),
      Text('Please keep this window open', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400])),
    ]));
  }

  // ─────────────────────────────────────────────────────────────────
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
        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
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
  // ─────────────────────────────────────────────────────────────────

  Widget _buildSlideCard(Map<String, dynamic> slide, int index) {
    final points   = (slide['points']  as List?) ?? [];
    final example  = _clean(slide['example']);
    final imgSug   = slide['image_suggestion'];
    final isRegen  = _regeneratingSlides.contains(index);

    return Container(
      decoration: BoxDecoration(
        color: _slideBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Stack(children: [
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

            Container(width: 60, height: 3, margin: const EdgeInsets.only(top: 4, bottom: 16),
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),

            // ── Points ─────────────────────────────────────────────
            ...points.map((p) {
                final headline = _clean((p as Map)['headline']?.toString());
                final detail   = _clean(p['detail']?.toString());
                return _buildPoint(headline, detail);
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
                  border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
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
                  color: _accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accent.withValues(alpha: 0.2)),
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
        border: Border.all(color: _accent.withValues(alpha: 0.15)),
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

  // ─────────────────────────────────────────────────────────────────
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
                  boxShadow: isActive ? [BoxShadow(color: _accent.withValues(alpha: 0.3), blurRadius: 8)] : [],
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