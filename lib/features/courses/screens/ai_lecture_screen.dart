import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:profound_app_frontend/core/constants/api_constants.dart';

const String _base = ApiConstants.baseUrl;
const int _kMaxSlides = 60;
const int _kMinSlides = 3;

class AILectureScreen extends StatefulWidget {
  const AILectureScreen({super.key});
  @override
  State<AILectureScreen> createState() => _AILectureScreenState();
}

class _AILectureScreenState extends State<AILectureScreen> {
  // Controllers
  final _topicCtrl        = TextEditingController();
  final _instrCtrl        = TextEditingController();
  final _refCtrl          = TextEditingController();
  final _countCtrl        = TextEditingController(text: '12');
  final _chatCtrl         = TextEditingController();
  final _pageCtrl         = PageController();
  final _chatScrollCtrl   = ScrollController();

  // Settings
  String _theme      = 'Modern Minimalist';

  // State

  // State
  bool   _isGenerating   = false;
  bool   _isExporting    = false;
  bool   _isChatBusy     = false;
  bool   _isFetchingImgs = false;
  bool   _showPanel      = true;
  bool   _showNotes      = true;
  int    _panelTab       = 0;   // 0=settings  1=chat edit
  String?   _lectureId;
  Map<String, dynamic>? _data;
  int       _slide       = 0;
  final Set<int>              _regenSet   = {};
  final Map<String, Uint8List?> _imgCache = {};
  final List<Map<String,dynamic>> _chatLog = [];

  PlatformFile? _uploadedFile;

  static const _themes = ['Modern Minimalist','Dark Mode Tech','Classic Academic','Vibrant Creative'];

  @override
  void dispose() {
    _topicCtrl.dispose(); _instrCtrl.dispose(); _refCtrl.dispose();
    _countCtrl.dispose(); _chatCtrl.dispose();  _pageCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  // ── Theme helpers ─────────────────────────────────────────────────
  Color get _ac {
    switch (_theme) {
      case 'Dark Mode Tech':   return const Color(0xFF38BDF8);
      case 'Classic Academic': return const Color(0xFF800000);
      case 'Vibrant Creative': return const Color(0xFFF97316);
      default:                 return const Color(0xFF4F46E5);
    }
  }
  Color get _bg   => _theme == 'Dark Mode Tech' ? const Color(0xFF0F172A) : Colors.white;
  Color get _txt  => _theme == 'Dark Mode Tech' ? Colors.white            : const Color(0xFF1F2937);
  Color get _sub  => _theme == 'Dark Mode Tech' ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
  Color get _det  => _theme == 'Dark Mode Tech' ? const Color(0xFFCBD5E1) : const Color(0xFF374151);

  String _cl(String? t) => (t ?? '').replaceAll('**','').replaceAll('*','').trim();

  // ── Generate lecture ──────────────────────────────────────────────
  Future<void> _generate() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) { _snack('Enter a topic', isError: true); return; }
    final count = int.tryParse(_countCtrl.text) ?? 12;
    if (count < _kMinSlides || count > _kMaxSlides) {
      _snack('Slides must be $_kMinSlides – $_kMaxSlides', isError: true); return;
    }
    setState(() { _isGenerating = true; _data = null; _slide = 0;
                  _showPanel = false; _imgCache.clear(); _chatLog.clear(); });

    try {
      String refContext = '';
      if (_uploadedFile != null) {
        try {
          final req = http.MultipartRequest('POST', Uri.parse('$_base/extract-text'));
          req.files.add(http.MultipartFile.fromBytes('file',
              _uploadedFile!.bytes!, filename: _uploadedFile!.name));
          final r = await http.Response.fromStream(
              await req.send().timeout(const Duration(seconds: 30)));
          if (r.statusCode == 200) {
            final txt = jsonDecode(r.body)['extracted_text'] as String? ?? '';
            refContext = txt.substring(0, txt.length.clamp(0, 2000));
          }
        } catch (_) {}
      }

      final instr = [
        if (_instrCtrl.text.trim().isNotEmpty) _instrCtrl.text.trim(),
        if (_refCtrl.text.trim().isNotEmpty) 'Reference: ${_refCtrl.text.trim()}',
      ].join(' ');

      final res = await http.post(
        Uri.parse('$_base/api/generate-lecture'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic':                   topic,
          'pages_count':             count,
          'additional_instructions': instr.isEmpty ? '' : instr,
          'theme':                   _theme,
          'reference_context':       refContext,
        }),
      ).timeout(const Duration(seconds: 420));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['slides'] is List && (d['slides'] as List).isNotEmpty) {
          setState(() {
            _lectureId = d['lecture_id'] as String?;
            _data      = {'slides': d['slides'], 'metadata': d['metadata']};
          });
          // Pre-fetch all DALL-E images in background (non-blocking)
          _prefetchAllImages(d['slides'] as List);
        } else {
          _snack('No slides returned', isError: true);
          setState(() => _showPanel = true);
        }
      } else {
        _snack(_errMsg(res.body), isError: true);
        setState(() => _showPanel = true);
      }
    } catch (e) {
      _snack('Network error: $e', isError: true);
      setState(() => _showPanel = true);
    } finally { setState(() => _isGenerating = false); }
  }

  // ── Chat edit ─────────────────────────────────────────────────────
  Future<void> _sendChat(String instruction) async {
    if (instruction.isEmpty || _data == null || _lectureId == null) return;
    setState(() {
      _isChatBusy = true;
      _chatLog.add({'role':'user','text':instruction});
    });
    _chatCtrl.clear();
    _scrollChat();

    try {
      final res = await http.post(
        Uri.parse('$_base/api/lecture/chat-edit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lecture_id':          _lectureId,
          'slides':              _data!['slides'],
          'instruction':         instruction,
          'topic':               _topicCtrl.text.trim(),
          'current_slide_index': _slide,
        }),
      ).timeout(const Duration(seconds: 180));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final newSlides = d['slides'] as List;
        final changedIdx = ((d['changed_indices'] as List?) ?? [])
            .map((e) => e as int).toSet();
        setState(() {
          _data = {..._data!, 'slides': newSlides};
          // Only drop cache entries for slides that actually changed —
          // previously this cleared the ENTIRE image cache on every edit,
          // which meant even a one-word tweak to slide 3 re-generated
          // (and re-billed) DALL-E images for every other slide too.
          for (final i in changedIdx) {
            if (i < newSlides.length) {
              final key = _imgKeyFor(newSlides[i] as Map);
              if (key.isNotEmpty) _imgCache.remove(key);
            }
          }
          _chatLog.add({'role':'ai','text': d['message'] ?? 'Done.'});
        });
        // Re-prefetch only pulls images not already cached, so unchanged
        // slides reuse their existing images instead of re-generating.
        _prefetchAllImages(newSlides);
      } else {
        setState(() => _chatLog.add({'role':'ai','text':_errMsg(res.body),'err':true}));
      }
    } catch (e) {
      setState(() => _chatLog.add({'role':'ai','text':'Error: $e','err':true}));
    } finally { setState(() => _isChatBusy = false); _scrollChat(); }
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(_chatScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ── Export PPTX (with images pre-fetched) ────────────────────────
  Future<void> _exportPptx() async {
    if (_data == null) return;
    setState(() => _isExporting = true);
    _snack('Preparing export (fetching images)...');
    try {
      // Pre-download all DALL-E images so the backend can embed them
      final slides = (_data!['slides'] as List).cast<Map<String,dynamic>>();
      final enriched = <Map<String,dynamic>>[];
      for (final s in slides) {
        final prompt = _imgKeyFor(s);
        Map<String,dynamic> sl = Map.from(s);
        if (prompt.isNotEmpty) {
          final bytes = await _fetchImg(prompt);
          if (bytes != null) {
            sl['image_bytes_b64'] = base64.encode(bytes);
          }
        }
        enriched.add(sl);
      }

      final res = await http.post(
        Uri.parse('$_base/api/export-pptx'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'slides': enriched, 'theme': _theme}),
      ).timeout(const Duration(seconds: 120));

      if (res.statusCode == 200) {
        final name = _topicCtrl.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'),'_');
        await FileSaver.instance.saveFile(
          name: 'Lecture_$name',
          bytes: res.bodyBytes,
          fileExtension: 'pptx',
          mimeType: MimeType.microsoftPresentation,
        );
        _snack('Saved Lecture_$name.pptx');
      } else { _snack(_errMsg(res.body), isError: true); }
    } catch (e) { _snack('Export failed: $e', isError: true); }
    finally { setState(() => _isExporting = false); }
  }

  // ── Regenerate single slide ───────────────────────────────────────
  Future<void> _regenSlide(int index) async {
    final slides = (_data?['slides'] as List?);
    if (slides == null) return;
    setState(() => _regenSet.add(index));
    try {
      final title = _cl(slides[index]['title']);
      await _sendChat('Completely rewrite slide ${index+1} "$title" with fresh, rich content.');
    } finally { setState(() => _regenSet.remove(index)); }
  }

  // ── DALL-E image fetch (cached) ───────────────────────────────────
  // Resolves the same effective key the UI panel uses: image_prompt,
  // falling back to image_keyword when the model left image_prompt empty.
  String _imgKeyFor(Map slide) {
    final prompt = _cl(slide['image_prompt']);
    if (prompt.isNotEmpty) return prompt;
    return _cl(slide['image_keyword']);
  }

  Future<Uint8List?> _fetchImg(String prompt) async {
    if (prompt.isEmpty) return null;
    if (_imgCache.containsKey(prompt)) return _imgCache[prompt];
    try {
      final r = await http.post(
        Uri.parse('$_base/api/generate-slide-image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_prompt': prompt}),
      ).timeout(const Duration(seconds: 75));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
        _imgCache[prompt] = r.bodyBytes;
        return r.bodyBytes;
      }
    } catch (e) {
      print('Image fetch error: $e');
    }
    _imgCache[prompt] = null;
    return null;
  }

  /// Pre-fetch ALL images in parallel — much faster than sequential.
  Future<void> _prefetchAllImages(List slides) async {
    setState(() => _isFetchingImgs = true);

    // Collect all unique prompts (falling back to image_keyword, same as the panel)
    final prompts = <String>{};
    for (final s in slides) {
      final p = _imgKeyFor(s as Map);
      if (p.isNotEmpty && !_imgCache.containsKey(p)) prompts.add(p);
    }

    if (prompts.isEmpty) {
      if (mounted) setState(() => _isFetchingImgs = false);
      return;
    }

    // Fetch all in parallel — limit to 5 concurrent to avoid rate limits
    final chunks = <List<String>>[];
    final list = prompts.toList();
    for (int i = 0; i < list.length; i += 5) {
      chunks.add(list.sublist(i, i + 5 > list.length ? list.length : i + 5));
    }

    for (final chunk in chunks) {
      if (!mounted) break;
      // Fire all in chunk simultaneously
      final futures = chunk.map((p) => _fetchImg(p)).toList();
      await Future.wait(futures);
      if (mounted) setState(() {}); // show newly loaded images
    }

    if (mounted) setState(() => _isFetchingImgs = false);
  }

  String _errMsg(String b) {
    try { return jsonDecode(b)['detail']?.toString() ?? b; } catch(_){ return b; }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      duration: const Duration(seconds: 4),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(children: [
        _buildTopBar(),
        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _showPanel ? 370 : 0,
            child: _showPanel ? ClipRect(child: SizedBox(width: 370, child: _buildPanel())) : null,
          ),
          Expanded(child: _buildMain()),
          if (_data != null) _buildThumbs(),
        ])),
      ]),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────
  Widget _buildTopBar() => Container(
    color: _ac,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    child: Row(children: [
      Text('AI Lecture Builder',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      const Spacer(),
      if (_data != null) ...[
        _topBtn(Icons.tune, 'Panel', () => setState(() => _showPanel = !_showPanel)),
        _topBtn(Icons.speaker_notes_outlined, 'Notes', () => setState(() => _showNotes = !_showNotes)),
        if (_isExporting)
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
        else
          _topBtn(Icons.download_rounded, 'Export .PPTX', _exportPptx),
      ],
    ]),
  );

  Widget _topBtn(IconData icon, String tip, VoidCallback fn) =>
      IconButton(icon: Icon(icon, color: Colors.white, size: 20), tooltip: tip, onPressed: fn);

  // ── Left panel (settings + chat tabs) ────────────────────────────
  Widget _buildPanel() => Container(
    color: Colors.white,
    child: Column(children: [
      // Tab bar
      Row(children: [
        _panelTabBtn(0, Icons.settings, 'Settings'),
        _panelTabBtn(1, Icons.chat_bubble_outline, 'AI Chat Edit'),
      ]),
      const Divider(height: 1),
      Expanded(child: _panelTab == 0 ? _buildSettingsTab() : _buildChatTab()),
    ]),
  );

  Widget _panelTabBtn(int idx, IconData icon, String label) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _panelTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _panelTab == idx ? _ac.withOpacity(0.08) : Colors.transparent,
          border: Border(bottom: BorderSide(
              color: _panelTab == idx ? _ac : Colors.transparent, width: 2.5)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: _panelTab == idx ? _ac : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: _panelTab == idx ? _ac : Colors.grey)),
        ]),
      ),
    ),
  );

  // ── Settings tab ─────────────────────────────────────────────────
  Widget _buildSettingsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl('Topic *'),
      TextField(controller: _topicCtrl, decoration: _dec('e.g., Relational Databases')),
      const SizedBox(height: 12),

      _lbl('Professor Instructions'),
      TextField(controller: _instrCtrl, maxLines: 3,
          decoration: _dec('e.g., Add real-world examples. Cover security implications.')),
      const SizedBox(height: 12),

      _lbl('Reference (Book name or URL)'),
      TextField(controller: _refCtrl,
          decoration: _dec('e.g., Database System Concepts — Silberschatz')),
      const SizedBox(height: 12),

      _lbl('Upload Reference (Optional)'),
      _buildUploadArea(),
      const SizedBox(height: 12),

      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl('Slides (3–60)'),
          TextField(controller: _countCtrl, keyboardType: TextInputType.number,
              decoration: _dec('12')),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl('Theme'),
          DropdownButtonFormField<String>(
            isExpanded: true, value: _theme, decoration: _dec(''),
            items: _themes.map((t) => DropdownMenuItem(value: t,
                child: Text(t, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => _theme = v!),
          ),
        ])),
      ]),
      const SizedBox(height: 20),

      SizedBox(width: double.infinity, height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _ac, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _isGenerating ? null : _generate,
          icon: _isGenerating
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_isGenerating ? 'Generating...' : 'Generate Lecture',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),
      if (_data != null) ...[
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green.shade600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _isExporting ? null : _exportPptx,
            icon: Icon(Icons.download, color: Colors.green.shade700),
            label: Text('Export as .PPTX',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
      const SizedBox(height: 16),
    ]),
  );

  Widget _buildUploadArea() => GestureDetector(
    onTap: () async {
      final r = await FilePicker.pickFiles(type: FileType.custom,
          allowedExtensions: ['pdf','docx','txt'], withData: true);
      if (r != null) setState(() => _uploadedFile = r.files.first);
    },
    child: Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _uploadedFile != null ? _ac.withOpacity(0.06) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _uploadedFile != null ? _ac : Colors.grey.shade300, width: 1.5),
      ),
      child: Row(children: [
        Icon(_uploadedFile != null ? Icons.check_circle_outline : Icons.upload_file_outlined,
            color: _uploadedFile != null ? _ac : Colors.grey, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(
          _uploadedFile != null ? _uploadedFile!.name : 'Upload PDF / DOCX / TXT',
          style: TextStyle(fontSize: 12, color: _uploadedFile != null ? _ac : Colors.grey),
          overflow: TextOverflow.ellipsis,
        )),
        if (_uploadedFile != null)
          GestureDetector(onTap: () => setState(() => _uploadedFile = null),
              child: const Icon(Icons.close, size: 15, color: Colors.grey)),
      ]),
    ),
  );

  // ── Chat Edit tab ─────────────────────────────────────────────────
  Widget _buildChatTab() => Column(children: [
    // Quick suggestions
    Container(
      padding: const EdgeInsets.fromLTRB(12,10,12,6),
      color: Colors.grey.shade50,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quick actions:', style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _chip('Rewrite slide 3'),
          _chip('Add more examples'),
          _chip('Make slide 4 simpler'),
          _chip('Add a code example'),
          _chip('Add quiz questions'),
          _chip('Expand slide 5'),
          _chip('Add case studies'),
          _chip('Make suitable for beginners'),
          _chip('Add discussion questions'),
          _chip('Convert slide 6 into two slides'),
        ]),
      ]),
    ),
    // Chat log
    Expanded(child: ListView.builder(
      controller: _chatScrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: _chatLog.length,
      itemBuilder: (_, i) {
        final m = _chatLog[i];
        final isUser = m['role'] == 'user';
        final isErr  = m['err'] == true;
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: isUser ? _ac : (isErr ? Colors.red.shade50 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(m['text'] ?? '',
                style: TextStyle(fontSize: 12,
                    color: isUser ? Colors.white : (isErr ? Colors.red.shade800 : Colors.black87))),
          ),
        );
      },
    )),
    // Input
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _chatCtrl, maxLines: 3, minLines: 1,
          decoration: _dec('Type any editing instruction...'),
          onSubmitted: (v) => _sendChat(v.trim()),
        )),
        const SizedBox(width: 8),
        _isChatBusy
            ? SizedBox(width: 40, height: 40,
                child: Center(child: CircularProgressIndicator(color: _ac, strokeWidth: 2)))
            : IconButton(
                icon: Icon(Icons.send_rounded, color: _ac, size: 26),
                onPressed: () => _sendChat(_chatCtrl.text.trim())),
      ]),
    ),
  ]);

  Widget _chip(String t) => GestureDetector(
    onTap: () => setState(() => _chatCtrl.text = t),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _ac.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _ac.withOpacity(0.2))),
      child: Text(t, style: TextStyle(fontSize: 10, color: _ac)),
    ),
  );

  // ── Main area ─────────────────────────────────────────────────────
  Widget _buildMain() {
    if (_isGenerating) return _buildLoading();
    if (_data == null)  return _buildEmpty();
    return _buildViewer();
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.slideshow_rounded, size: 80, color: Colors.grey.shade300),
    const SizedBox(height: 20),
    Text('Your lecture will appear here',
        style: GoogleFonts.inter(fontSize: 18, color: Colors.grey.shade500)),
    const SizedBox(height: 8),
    Text('Configure settings and click Generate',
        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400)),
    if (!_showPanel) ...[
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: () => setState(() => _showPanel = true),
        icon: const Icon(Icons.settings), label: const Text('Open Settings'),
        style: ElevatedButton.styleFrom(backgroundColor: _ac, foregroundColor: Colors.white),
      ),
    ],
  ]));

  Widget _buildLoading() {
    final n = int.tryParse(_countCtrl.text) ?? 12;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: _ac),
      const SizedBox(height: 24),
      Text('Generating your lecture with GPT-4o...',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _ac)),
      const SizedBox(height: 8),
      Text('$n slides — GPT-4o generating rich content',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
      const SizedBox(height: 4),
      Text('This takes ~30–60 seconds for rich content',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
    ]));
  }

  Widget _buildViewer() {
    final slides = _data!['slides'] as List;
    final slide  = slides[_slide] as Map<String, dynamic>;
    return Column(children: [
      _buildNavBar(slides.length),
      Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: PageView.builder(
          controller: _pageCtrl,
          onPageChanged: (i) => setState(() => _slide = i),
          itemCount: slides.length,
          itemBuilder: (_, i) => _buildSlideCard(slides[i] as Map<String,dynamic>, i),
        ),
      )),
      if (_showNotes) _buildNotes(slide),
    ]);
  }

  Widget _buildNavBar(int total) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: _ac.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Text('${_slide + 1} / $total',
            style: TextStyle(color: _ac, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      const Spacer(),
      IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded,
            color: _slide > 0 ? _ac : Colors.grey.shade300, size: 20),
        onPressed: _slide > 0
            ? () => _pageCtrl.previousPage(
                duration: const Duration(milliseconds: 250), curve: Curves.easeInOut)
            : null),
      IconButton(
        icon: Icon(Icons.arrow_forward_ios_rounded,
            color: _slide < total - 1 ? _ac : Colors.grey.shade300, size: 20),
        onPressed: _slide < total - 1
            ? () => _pageCtrl.nextPage(
                duration: const Duration(milliseconds: 250), curve: Curves.easeInOut)
            : null),
    ]),
  );

  // ── Slide card ────────────────────────────────────────────────────
  Widget _buildSlideCard(Map<String,dynamic> sd, int idx) {
    final pts       = (sd['points']             as List?) ?? [];
    final example   = _cl(sd['example']);
    final practical = _cl(sd['practical_example']);
    final industry  = _cl(sd['industry_example']);
    final analogy   = _cl(sd['analogy']);
    final code      = _cl(sd['code_example']);
    final codeLang  = _cl(sd['code_language']);
    final diagram   = _cl(sd['diagram']);
    final imgPrompt = _cl(sd['image_prompt']);
    final imgKw     = _cl(sd['image_keyword']);
    final quizQs    = (sd['quiz_questions']       as List?) ?? [];
    final discQs    = (sd['discussion_questions'] as List?) ?? [];
    final assigns   = (sd['assignments']           as List?) ?? [];
    final tips      = (sd['tips']                  as List?) ?? [];
    final mistakes  = (sd['common_mistakes']       as List?) ?? [];
    final isRegen   = _regenSet.contains(idx);
    final hasImg    = imgPrompt.isNotEmpty || imgKw.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: _bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _ac.withOpacity(0.2), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
              blurRadius: 18, offset: const Offset(0,4))]),
      child: isRegen
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: _ac),
              const SizedBox(height: 10),
              Text('Rewriting…', style: TextStyle(color: _ac)),
            ]))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18,14,14,14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: _ac, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Expanded(child: Text(_cl(sd['title']), style: GoogleFonts.inter(
                        fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white))),
                    GestureDetector(onTap: () => _regenSlide(idx),
                        child: const Icon(Icons.refresh, color: Colors.white70, size: 18)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() { _showPanel = true; _panelTab = 1;
                          _chatCtrl.text = 'Rewrite slide ${idx+1}'; });
                      },
                      child: const Icon(Icons.edit_note, color: Colors.white70, size: 18)),
                  ]),
                ),
                const SizedBox(height: 12),

                // Two-column: bullets + image
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    flex: hasImg ? 6 : 10,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: pts.map((p) => _buildBullet(
                            _cl((p as Map)['headline']?.toString()),
                            _cl(p['detail']?.toString()))).toList()),
                  ),
                  if (hasImg) ...[
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: _buildImgPanel(imgPrompt, imgKw)),
                  ],
                ]),

                // Examples
                if (example.isNotEmpty || practical.isNotEmpty ||
                    industry.isNotEmpty || analogy.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildExamples(example, practical, industry, analogy),
                ],

                // Code
                if (code.isNotEmpty) ...[const SizedBox(height: 10), _buildCode(code, codeLang)],

                // Diagram
                if (diagram.isNotEmpty) ...[const SizedBox(height: 10), _buildDiagram(diagram)],

                // Tips
                if (tips.isNotEmpty) ...[const SizedBox(height: 10),
                  _buildList('💡 Tips', tips, const Color(0xFF0369A1), const Color(0xFFE0F2FE))],

                // Mistakes
                if (mistakes.isNotEmpty) ...[const SizedBox(height: 10),
                  _buildList('⚠️ Common Mistakes', mistakes, const Color(0xFFB91C1C), const Color(0xFFFEE2E2))],

                // Quiz
                if (quizQs.isNotEmpty) ...[const SizedBox(height: 12), _buildQuiz(quizQs)],

                // Discussion
                if (discQs.isNotEmpty) ...[const SizedBox(height: 10),
                  _buildList('💬 Discussion Questions', discQs, const Color(0xFF7C3AED), const Color(0xFFF5F3FF))],

                // Assignments
                if (assigns.isNotEmpty) ...[const SizedBox(height: 10),
                  _buildList('📝 Assignments', assigns, const Color(0xFF065F46), const Color(0xFFECFDF5))],
              ]),
            ),
    );
  }

  Widget _buildBullet(String hl, String det) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.arrow_right_rounded, color: _ac, size: 22),
      const SizedBox(width: 4),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(hl, style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w800, color: _txt, height: 1.3)),
        if (det.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(det.length > 180 ? '${det.substring(0,177)}…' : det,
              style: GoogleFonts.inter(fontSize: 12, height: 1.55, color: _det)),
        ],
      ])),
    ]),
  );

  // DALL-E image panel — reads from pre-fetched cache (no FutureBuilder)
  Widget _buildImgPanel(String prompt, String kw) {
    if (prompt.isEmpty && kw.isEmpty) return const SizedBox.shrink();
    final key = prompt.isNotEmpty ? prompt : kw;

    if (_imgCache.containsKey(key)) {
      final bytes = _imgCache[key];
      if (bytes != null && bytes.isNotEmpty) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _ac.withOpacity(0.2)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(bytes,
              height: 190,
              width: double.infinity,
              fit: BoxFit.contain,   // ← contain, not cover — no cropping
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // Still loading
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: _ac.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ac.withOpacity(0.2)),
      ),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(color: _ac, strokeWidth: 2)),
        const SizedBox(height: 6),
        Text('Generating image…',
            style: TextStyle(fontSize: 10, color: _ac.withOpacity(0.7))),
      ])),
    );
  }

  Widget _buildExamples(String main, String practical, String industry, String analogy) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _bg == Colors.white ? const Color(0xFFECFDF5) : const Color(0xFF0C2A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.lightbulb_outline, size: 13, color: Color(0xFF059669)),
            SizedBox(width: 5),
            Text('EXAMPLES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                color: Color(0xFF059669), letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          if (main.isNotEmpty)       _exRow('Real World', main,      Icons.public),
          if (practical.isNotEmpty)  _exRow('Practical',  practical, Icons.build_outlined),
          if (industry.isNotEmpty)   _exRow('Industry',   industry,  Icons.business_outlined),
          if (analogy.isNotEmpty)    _exRow('Analogy',    analogy,   Icons.compare_arrows),
        ]),
      );

  Widget _exRow(String lbl, String txt, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 12, color: const Color(0xFF059669)),
      const SizedBox(width: 5),
      Expanded(child: RichText(text: TextSpan(children: [
        TextSpan(text: '$lbl: ', style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
        TextSpan(text: txt, style: const TextStyle(fontSize: 12,
            color: Color(0xFF065F46), height: 1.5)),
      ]))),
    ]),
  );

  Widget _buildCode(String code, String lang) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.code, size: 12, color: Color(0xFF89B4FA)),
        const SizedBox(width: 5),
        Text(lang.isEmpty ? 'CODE' : lang.toUpperCase(), style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold,
            color: Color(0xFF89B4FA), letterSpacing: 1)),
      ]),
      const SizedBox(height: 6),
      SelectableText(code, style: const TextStyle(fontFamily: 'monospace',
          fontSize: 12, color: Color(0xFFCDD6F4), height: 1.6)),
    ]),
  );

  Widget _buildDiagram(String mermaid) {
    final enc = base64Url.encode(utf8.encode(mermaid.trim()));
    return Container(
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ac.withOpacity(0.25))),
      child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: _ac.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
          child: Row(children: [
            Icon(Icons.account_tree_outlined, size: 13, color: _ac),
            const SizedBox(width: 6),
            Text('DIAGRAM', style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.bold, color: _ac, letterSpacing: 1)),
          ])),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
          child: Image.network('https://mermaid.ink/img/$enc',
            width: double.infinity, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Padding(
              padding: const EdgeInsets.all(10),
              child: Text(mermaid, style: TextStyle(fontFamily: 'monospace',
                  fontSize: 11, color: _txt, height: 1.5))),
            loadingBuilder: (_, child, prog) => prog == null ? child :
                Container(height: 60, alignment: Alignment.center,
                    child: CircularProgressIndicator(color: _ac, strokeWidth: 2)),
          ),
        ),
      ]),
    );
  }

  Widget _buildList(String title, List items, Color color, Color bg) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
          color: color, letterSpacing: 0.8)),
      const SizedBox(height: 7),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          Expanded(child: Text(item.toString(),
              style: TextStyle(fontSize: 12, color: color, height: 1.5))),
        ]),
      )),
    ]),
  );

  Widget _buildQuiz(List qs) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.quiz_outlined, size: 13, color: Color(0xFF7C3AED)),
        SizedBox(width: 5),
        Text('QUIZ QUESTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
            color: Color(0xFF7C3AED), letterSpacing: 1)),
      ]),
      const SizedBox(height: 8),
      ...qs.asMap().entries.map((e) {
        final q = e.value;
        if (q is! Map) return Text(q.toString());
        final opts = (q['options'] as List?) ?? [];
        return Padding(padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e.key+1}. ${q['question'] ?? ''}', style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3B0764))),
            const SizedBox(height: 4),
            ...opts.map((o) => Padding(padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(o.toString(), style: const TextStyle(
                  fontSize: 12, color: Color(0xFF4C1D95))))),
          ]));
      }),
    ]),
  );

  Widget _buildNotes(Map<String,dynamic> slide) {
    final notes = _cl(slide['speaker_notes']);
    if (notes.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ac.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.speaker_notes_outlined, size: 14, color: _ac),
          const SizedBox(width: 6),
          Text('Speaker Notes', style: GoogleFonts.inter(
              fontWeight: FontWeight.bold, fontSize: 12, color: _ac)),
        ]),
        const SizedBox(height: 6),
        Text(notes, style: GoogleFonts.inter(fontSize: 11, height: 1.6, color: _sub)),
      ]),
    );
  }

  // ── Thumbnails ────────────────────────────────────────────────────
  Widget _buildThumbs() {
    final slides = (_data!['slides'] as List);
    return Container(
      width: 155,
      color: const Color(0xFFF8FAFC),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(10),
            child: Text('Slides', style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
        Expanded(child: ListView.builder(
          itemCount: slides.length,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          itemBuilder: (_, i) {
            final s      = slides[i] as Map<String,dynamic>;
            final active = i == _slide;
            return GestureDetector(
              onTap: () { _pageCtrl.jumpToPage(i); setState(() => _slide = i); },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: active ? _ac : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: active ? _ac : Colors.grey.shade200),
                  boxShadow: active ? [BoxShadow(color: _ac.withOpacity(0.3), blurRadius: 6)] : [],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i+1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                      color: active ? Colors.white70 : Colors.grey)),
                  const SizedBox(height: 2),
                  Text(_cl(s['title']), maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                          color: active ? Colors.white : Colors.black87)),
                ]),
              ),
            );
          },
        )),
      ]),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────
  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600,
        fontSize: 12, color: Color(0xFF374151))),
  );

  InputDecoration _dec(String hint, {String? helper}) => InputDecoration(
    hintText: hint, helperText: helper, helperMaxLines: 2,
    helperStyle: const TextStyle(fontSize: 10),
    filled: true, fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _ac, width: 1.5)),
    isDense: true,
  );
}