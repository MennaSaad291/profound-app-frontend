import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AILectureScreen extends StatefulWidget {
  const AILectureScreen({super.key});

  @override
  State<AILectureScreen> createState() => _AILectureScreenState();
}

class _AILectureScreenState extends State<AILectureScreen> {
  final _topicController = TextEditingController();
  final _instructionsController = TextEditingController();
  
  String _selectedLevel = 'Undergraduate (Introductory)';
  int _selectedPageCount = 10;
  String _selectedTheme = 'Modern Minimalist';
  bool _includeMedia = true;
  
  bool _isGenerating = false;
  bool _isExporting = false;
  Map<String, dynamic>? _presentationData;
  final PageController _pageController = PageController();
  int _currentSlide = 0;

  final List<String> _levels = ['Undergraduate (Introductory)', 'Undergraduate (Advanced)', 'Graduate / Master', 'PhD Seminar'];
  final List<int> _pageCounts = [5, 7, 10, 14, 20];
  final List<String> _themes = ['Modern Minimalist', 'Dark Mode Tech', 'Classic Academic', 'Vibrant Creative'];

  Future<void> _generateLecture() async {
    if (_topicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a lecture topic")));
      return;
    }

    setState(() { _isGenerating = true; _presentationData = null; _currentSlide = 0; });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/generate-lecture'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "topic": _topicController.text,
          "course_level": _selectedLevel,
          "pages_count": _selectedPageCount,
          "additional_instructions": _instructionsController.text.isNotEmpty ? _instructionsController.text : "Make it a deep, highly detailed academic overview.",
          "include_media": _includeMedia,
          "theme": _selectedTheme,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        bool valid = decoded is Map && decoded['slides'] is List && (decoded['slides'] as List).isNotEmpty;
        if (!valid) {
          // no usable slides
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Server returned no slides, please try again.")));
          setState(() => _presentationData = null);
        } else {
          // decoded comes from jsonDecode which returns Map<dynamic,dynamic>; convert to Map<String,dynamic>
          setState(() => _presentationData = Map<String, dynamic>.from(decoded));
        }
      } else {
        // show server message (possibly detailed error)
        String msg;
        try {
          final m = jsonDecode(response.body);
          msg = m['detail']?.toString() ?? response.body;
        } catch (_) {
          msg = response.body;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $msg")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Network Error: $e")));
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportToPowerPoint() async {
    if (_presentationData == null) return;
    setState(() => _isExporting = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/export-pptx'),
        headers: {"Content-Type": "application/json"},
        // IMPORTANT: We now send the chosen theme to the backend!
        body: jsonEncode({
          "slides": _presentationData!['slides'],
          "theme": _selectedTheme 
        }),
      );

      if (response.statusCode == 200) {
        Directory? dir = await getDownloadsDirectory();
        dir ??= await getApplicationDocumentsDirectory(); 
        
        String cleanTopic = _topicController.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        String filePath = '${dir.path}\\Lecture_$cleanTopic.pptx';
        
        File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("PowerPoint saved to Downloads: $filePath"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Failed: $e")));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Color _getBgColor() {
    if (_selectedTheme == 'Dark Mode Tech') return const Color(0xFF1E293B);
    if (_selectedTheme == 'Classic Academic') return const Color(0xFFFDFBF7);
    if (_selectedTheme == 'Vibrant Creative') return const Color(0xFFFFF7ED);
    return Colors.white; 
  }
  
  Color _getSecondaryBgColor() {
    if (_selectedTheme == 'Dark Mode Tech') return const Color(0xFF334155);
    if (_selectedTheme == 'Classic Academic') return const Color(0xFFF5F0E8);
    if (_selectedTheme == 'Vibrant Creative') return const Color(0xFFFEF2E8);
    return const Color(0xFFF8F9FE);
  }
  
  Color _getTextColor() => _selectedTheme == 'Dark Mode Tech' ? Colors.white : const Color(0xFF0F172A);
  
  Color _getSecondaryTextColor() => _selectedTheme == 'Dark Mode Tech' ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  
  Color _getAccentColor() {
    if (_selectedTheme == 'Dark Mode Tech') return const Color(0xFF38BDF8);
    if (_selectedTheme == 'Classic Academic') return const Color(0xFF8B1A1A);
    if (_selectedTheme == 'Vibrant Creative') return const Color(0xFFF97316);
    return const Color(0xFF9333EA); 
  }
  
  Color _getAccentColor2() {
    if (_selectedTheme == 'Dark Mode Tech') return const Color(0xFF06B6D4);
    if (_selectedTheme == 'Classic Academic') return const Color(0xFFD4844F);
    if (_selectedTheme == 'Vibrant Creative') return const Color(0xFFEC4899);
    return const Color(0xFFEC4899);
  }
  
  String _cleanText(String text) {
    return text.replaceAll('**', '').replaceAll('*', '').trim();
  }

  String _formatSpeakerNotes(dynamic notes) {
    if (notes == null) return 'No speaker notes provided.';
    if (notes is List) return notes.map((s) => _cleanText(s.toString())).join('\n\n');
    return _cleanText(notes.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9333EA),
        foregroundColor: Colors.white,
        title: Text("AI Presentation Builder", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT PANEL: Builder
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Design Your Slides", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextField(controller: _topicController, decoration: InputDecoration(labelText: "Main Topic", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 20),
                    TextField(controller: _instructionsController, maxLines: 4, decoration: InputDecoration(labelText: "Custom Instructions & Sources", hintText: "e.g., 'Make it highly detailed, use textbook references.'", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(isExpanded: true, value: _selectedTheme, decoration: InputDecoration(labelText: "Presentation Theme", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: _themes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (val) => setState(() => _selectedTheme = val!)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedLevel,
                          decoration: InputDecoration(labelText: "Level", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: _levels
                              .map((lvl) => DropdownMenuItem(value: lvl, child: Text(lvl, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedLevel = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          value: _selectedPageCount,
                          decoration: InputDecoration(labelText: "Slide Count", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: _pageCounts
                              .map((cnt) => DropdownMenuItem(value: cnt, child: Text(cnt.toString(), style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedPageCount = val!),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    SwitchListTile(title: const Text("Include Media Links", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: const Text("Generate clickable YouTube links", style: TextStyle(fontSize: 11)), value: _includeMedia, activeColor: const Color(0xFF9333EA), onChanged: (val) => setState(() => _includeMedia = val)),
                    const SizedBox(height: 32),
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _isGenerating ? null : _generateLecture, icon: _isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: Text(_isGenerating ? "Designing..." : "Generate Presentation", style: const TextStyle(fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
            ),
          ),

          // RIGHT PANEL: Slide Viewer
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(24),
              child: _presentationData == null && !_isGenerating
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.slideshow, size: 80, color: Colors.grey.shade300), const SizedBox(height: 16), Text("Your detailed slides will appear here.", style: TextStyle(color: Colors.grey.shade500, fontSize: 18))]))
                  : _isGenerating
                      ? const Center(child: CircularProgressIndicator())
                      : _buildSlideViewer(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideViewer() {
    final slides = (_presentationData?['slides'] as List<dynamic>?) ?? [];

    if (slides.isEmpty) {
      return Center(child: Text("Error parsing data. Try again.", style: TextStyle(color: Colors.red.shade400)));
    }

    return Column(
      children: [
        // CONTROLS & EXPORT BUTTON
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Slide ${_currentSlide + 1} of ${slides.length}", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportToPowerPoint,
                  style: ElevatedButton.styleFrom(backgroundColor: _getAccentColor(), foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF9333EA))),
                  icon: _isExporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.download, size: 18),
                  label: const Text("Export .PPTX", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: _currentSlide > 0 ? _getAccentColor() : Colors.grey.shade300),
                  onPressed: _currentSlide > 0 ? () { _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); } : null,
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, color: _currentSlide < slides.length - 1 ? _getAccentColor() : Colors.grey.shade300),
                  onPressed: _currentSlide < slides.length - 1 ? () { _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); } : null,
                ),
              ],
            ),
    // close outer Row
      ],
    ),
        const SizedBox(height: 16),
        
        // 16:9 SLIDE CONTAINER WITH PROFESSIONAL THEME
        Expanded(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentSlide = idx),
              itemCount: slides.length,
              itemBuilder: (context, index) {
                final slide = slides[index] as Map<String, dynamic>? ?? {};
                final contentList = (slide['content'] as List<dynamic>?) ?? [];
                final mediaUrl = slide['media_url']?.toString() ?? "";
                final mediaText = slide['media_text']?.toString() ?? "View recommended media";

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _getBgColor(),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: _getAccentColor().withOpacity(0.15), blurRadius: 25, offset: const Offset(0, 10)),
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15)
                    ],
                    border: Border.all(color: _getAccentColor().withOpacity(0.25), width: 2),
                  ),
                  child: Stack(
                    children: [
                      // DECORATIVE BACKGROUND ELEMENTS
                      Positioned(
                        top: -100,
                        right: -50,
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getAccentColor().withOpacity(0.08),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getAccentColor2().withOpacity(0.05),
                          ),
                        ),
                      ),
                      
                      // SLIDE CONTENT
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SLIDE TITLE
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getAccentColor().withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "Slide ${index + 1}",
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _getAccentColor(), letterSpacing: 0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _cleanText(slide['title']?.toString() ?? "Untitled Slide"),
                                    style: GoogleFonts.inter(fontSize: 44, fontWeight: FontWeight.w800, color: _getTextColor(), height: 1.2),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            
                            // TITLE UNDERLINE
                            Container(
                              width: 80,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _getAccentColor(),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // CONTENT POINTS WITH FLEXIBLE LAYOUT
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: contentList.map((point) {
                                    String cleanPoint = _cleanText(point.toString());
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 20),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(top: 8, right: 16),
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: _getAccentColor(),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          Expanded(
                                            child: SelectableText(
                                              cleanPoint,
                                              style: GoogleFonts.inter(
                                                fontSize: 18,
                                                height: 1.6,
                                                color: _getSecondaryTextColor(),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // MEDIA LINK SECTION
                            if (mediaUrl.isNotEmpty && mediaUrl != "null")
                              Container(
                                decoration: BoxDecoration(
                                  color: _getAccentColor().withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _getAccentColor().withOpacity(0.4), width: 1.5),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => launchUrl(Uri.parse(mediaUrl), mode: LaunchMode.externalApplication),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_circle_filled, color: _getAccentColor(), size: 28),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _cleanText(mediaText),
                                              style: GoogleFonts.inter(
                                                color: _getAccentColor(),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        
        // SPEAKER NOTES SECTION
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _getSecondaryBgColor(),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getAccentColor().withOpacity(0.15), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.speaker_notes_rounded, size: 20, color: _getAccentColor()),
                  const SizedBox(width: 10),
                  Text("Speaker Notes", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _getTextColor()))
                ],
              ),
              const SizedBox(height: 12),
              Text(
                (slides.isNotEmpty && _currentSlide < slides.length) ? _formatSpeakerNotes(slides[_currentSlide]['speaker_notes']) : "",
                style: GoogleFonts.inter(fontSize: 13, height: 1.6, color: _getSecondaryTextColor()),
              ),
            ],
          ),
        )
      ],
    );
  }
}