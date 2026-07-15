import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:math';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:profound_app_frontend/core/constants/api_constants.dart';

class AIExamGenerator extends StatefulWidget {
  const AIExamGenerator({super.key});

  @override
  State<AIExamGenerator> createState() => _AIExamGeneratorState();
}

class _AIExamGeneratorState extends State<AIExamGenerator> {
  String selectedTypeMode = 'MCQ';
  String selectedDifficultyMode = 'Medium';
  String selectedBlooms = 'Apply';
  int selectedQuestions = 5;
  double mcqPercentage = 70;
  bool isLoading = false;
  bool isGeneratingVariations = false;
  String? currentExamId;
  List<dynamic> generatedQuestions = [];

  // ── Content-upload mode ──────────────────────────────────────────
  bool _fromContent = false;
  PlatformFile? _contentFile;

  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _questionsController =
      TextEditingController(text: '5');

  List<String> get resolvedTypes {
    if (selectedTypeMode == 'Mix') return ['MCQ', 'Essay'];
    return [selectedTypeMode];
  }

  Map<String, int> _mixDistribution(int total) {
    final int mcqCount = (total * mcqPercentage / 100).round().clamp(0, total);
    final int essayCount = total - mcqCount;
    return {'MCQ': mcqCount, 'Essay': essayCount};
  }

  List<String> get resolvedDifficulties {
    if (selectedDifficultyMode == 'All') return ['Easy', 'Medium', 'Hard'];
    return [selectedDifficultyMode];
  }

  Map<String, int> _distributeQuestions(
      List<String> types, List<String> difficulties, int total) {
    final Map<String, int> distribution = {};
    final List<String> combos = [];

    for (String t in types) {
      for (String d in difficulties) {
        combos.add('$t|$d');
      }
    }

    if (combos.length == 1) {
      distribution[combos[0]] = total;
      return distribution;
    }

    final rand = Random();
    int remaining = total;

    for (int i = 0; i < combos.length - 1; i++) {
      final maxForThis = remaining - (combos.length - 1 - i);
      final assigned = maxForThis <= 1 ? 1 : (rand.nextInt(maxForThis - 1) + 1);
      distribution[combos[i]] = assigned;
      remaining -= assigned;
    }
    distribution[combos.last] = remaining;

    return distribution;
  }

  Future<void> _downloadExamToDevice(String examId) async {
    setState(() => isLoading = true);
    try {
    final url = '${ApiConstants.baseUrl}/exams/export-word/$examId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Server returned ${response.statusCode}');
      final blob = html.Blob([response.bodyBytes],
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: blobUrl)
        ..setAttribute('download', 'Profound_Exam_$examId.docx')
        ..click();
      html.Url.revokeObjectUrl(blobUrl);
      if (mounted) _snack("Exam downloaded!");
    } catch (e) {
      if (mounted) _snack("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _downloadVariations(String examId, int numVariations) async {
    setState(() => isGeneratingVariations = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/exams/$examId/variations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'num_variations': numVariations}),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final blob = html.Blob([response.bodyBytes], 'application/zip');
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: blobUrl)
          ..setAttribute('download', 'Exam_Variations_$examId.zip')
          ..click();
        html.Url.revokeObjectUrl(blobUrl);
        if (mounted) _snack("$numVariations variations downloaded!");
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _snack("Error generating variations: $e", isError: true);
    } finally {
      if (mounted) setState(() => isGeneratingVariations = false);
    }
  }

  void _showVariationsDialog() {
    final numController = TextEditingController(text: '3');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.copy_all_outlined, color: Color(0xFF4F46E5)),
          SizedBox(width: 8),
          Text('Generate Exam Versions', style: TextStyle(fontSize: 18)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Create multiple shuffled versions of this exam.\nEach version has a unique question order and shuffled MCQ options — ideal for preventing cheating.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: numController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Number of Versions (2–10)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.format_list_numbered),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              _varFeature('Questions shuffled uniquely per version'),
              _varFeature('MCQ options reshuffled per version'),
              _varFeature('Answer key included for each version'),
              _varFeature('Downloaded as a single ZIP file'),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final n = int.tryParse(numController.text) ?? 3;
              final clamped = n.clamp(2, 10);
              Navigator.pop(ctx);
              _downloadVariations(currentExamId!, clamped);
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Generate Versions'),
          ),
        ],
      ),
    );
  }

  Widget _varFeature(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      const Icon(Icons.check, color: Color(0xFF4F46E5), size: 16),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 12)),
    ]),
  );

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _handleGenerateExam() async {
    if (_topicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a topic first!"), backgroundColor: Colors.red),
      );
      return;
    }

    final int? parsed = int.tryParse(_questionsController.text);
    if (parsed == null || parsed < 1 || parsed > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid number between 1 and 50"), backgroundColor: Colors.red),
      );
      return;
    }
    selectedQuestions = parsed;

    setState(() { isLoading = true; generatedQuestions = []; currentExamId = null; });

    try {
      // ── Content-based generation (upload mode) ─────────────────
      if (_fromContent && _contentFile != null) {
        // When 'All' difficulty is selected, generate questions across all 3 levels
        final difficulties = selectedDifficultyMode == 'All'
            ? ['Easy', 'Medium', 'Hard']
            : [selectedDifficultyMode];

        List<dynamic> allContentQuestions = [];
        String? contentExamId;

        // Distribute questions evenly across selected difficulties
        final Map<String, int> diffCounts = {};
        if (difficulties.length == 1) {
          diffCounts[difficulties[0]] = selectedQuestions;
        } else {
          // Guard: can't split fewer questions than difficulty levels
          final usedDiffs = difficulties.take(selectedQuestions).toList();
          int rem = selectedQuestions;
          for (int i = 0; i < usedDiffs.length - 1; i++) {
            final int maxShare = rem - (usedDiffs.length - 1 - i);
            if (maxShare < 1) break;
            final share = (selectedQuestions / usedDiffs.length).floor().clamp(1, maxShare);
            diffCounts[usedDiffs[i]] = share;
            rem -= share;
          }
          if (rem > 0) diffCounts[usedDiffs.last] = rem;
        }

        for (final entry in diffCounts.entries) {
          if (entry.value == 0) continue;
          final request = http.MultipartRequest(
              'POST', Uri.parse('${ApiConstants.baseUrl}/exams/generate-from-content'));
          // Clone the file bytes for each request
          final fileBytes = _contentFile!.bytes!;
          request.fields['topic']               = _topicController.text.trim();
          request.fields['number_of_questions'] = entry.value.toString();
          request.fields['difficulty']          = entry.key;
          request.fields['blooms_level']        = selectedBlooms;
          request.fields['question_type']       = selectedTypeMode;
          request.fields['mcq_percentage']      = mcqPercentage.round().toString();
          // Pass existing exam_id on subsequent calls so all questions go to same exam
          if (contentExamId != null) {
            request.fields['existing_exam_id'] = contentExamId;
          }
          request.files.add(http.MultipartFile.fromBytes(
              'content_file', fileBytes, filename: _contentFile!.name));

          final streamedRes = await request.send().timeout(const Duration(seconds: 120));
          final res         = await http.Response.fromStream(streamedRes);

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            contentExamId ??= data['exam_id'];
            allContentQuestions.addAll(data['questions'] ?? []);
          } else {
            throw Exception("Server error: ${res.statusCode} — ${res.body}");
          }
        }

        setState(() {
          currentExamId      = contentExamId;
          generatedQuestions = allContentQuestions;
        });
        return;
      }

      // ── Topic-based generation (original mode) ─────────────────
      final List<String> difficulties = resolvedDifficulties;
      List<dynamic> allQuestions = [];
      String? examId;

      final Map<String, int> typeMap = selectedTypeMode == 'Mix'
          ? _mixDistribution(selectedQuestions)
          : {selectedTypeMode: selectedQuestions};

      for (final typeEntry in typeMap.entries) {
        final String type = typeEntry.key;
        final int typeTotal = typeEntry.value;
        if (typeTotal == 0) continue;

        final Map<String, int> diffMap = {};
        if (difficulties.length == 1) {
          diffMap[difficulties[0]] = typeTotal;
        } else {
          // Guard: if typeTotal < difficulties.length, only use as many levels as we have questions
          final usedDiffs = difficulties.take(typeTotal).toList();
          int rem = typeTotal;
          for (int i = 0; i < usedDiffs.length - 1; i++) {
            final int maxShare = rem - (usedDiffs.length - 1 - i);
            if (maxShare < 1) break;
            final int share = (typeTotal / usedDiffs.length).floor().clamp(1, maxShare);
            diffMap[usedDiffs[i]] = share;
            rem -= share;
          }
          if (rem > 0) diffMap[usedDiffs.last] = rem;
        }

        for (final diffEntry in diffMap.entries) {
          final String difficulty = diffEntry.key;
          int remaining = diffEntry.value;
          if (remaining == 0) continue;

          const int batchSize = 5;
          while (remaining > 0) {
            final int batchCount = remaining > batchSize ? batchSize : remaining;

            // Build request body — add existing_exam_id only after first batch
            final Map<String, dynamic> reqBody = {
              "topic": _topicController.text,
              "number_of_questions": batchCount,
              "difficulty": difficulty,
              "blooms_level": selectedBlooms,
              "question_type": type,
            };
            if (examId != null) reqBody["existing_exam_id"] = examId;

            final response = await http.post(
              Uri.parse('${ApiConstants.baseUrl}/exams/generate'),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(reqBody),
            ).timeout(const Duration(seconds: 300));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              examId ??= data['exam_id'];
              allQuestions.addAll(data['questions']);
            } else {
              throw Exception("Server Error: ${response.statusCode} - ${response.body}");
            }
            remaining -= batchCount;
          }
        }
      }

      if (allQuestions.length > selectedQuestions) {
        allQuestions = allQuestions.sublist(0, selectedQuestions);
      }

      setState(() { currentExamId = examId; generatedQuestions = allQuestions; });

    } catch (e, stack) {
      print("=== ERROR ===\n$e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  const SizedBox(height: 16),
                  Text(
                    "Generating your exam...\n(${resolvedTypes.length * resolvedDifficulties.length} combination(s))",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF4F46E5)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Source toggle ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Expanded(child: GestureDetector(
                        onTap: () => setState(() { _fromContent = false; _contentFile = null; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_fromContent ? const Color(0xFF4F46E5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.edit_outlined, size: 16, color: !_fromContent ? Colors.white : Colors.grey),
                            const SizedBox(width: 6),
                            Text('From Topic', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: !_fromContent ? Colors.white : Colors.grey)),
                          ]),
                        ),
                      )),
                      Expanded(child: GestureDetector(
                        onTap: () => setState(() => _fromContent = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _fromContent ? const Color(0xFF4F46E5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.upload_file_outlined, size: 16, color: _fromContent ? Colors.white : Colors.grey),
                            const SizedBox(width: 6),
                            Text('From Content', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _fromContent ? Colors.white : Colors.grey)),
                          ]),
                        ),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  _buildStepHeader("1", "Exam Topic"),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _topicController,
                    decoration: _inputDecoration("e.g., Data Structures"),
                  ),

                  // ── Content upload (only in content mode) ───────────────
                  if (_fromContent) ...[
                    const SizedBox(height: 16),
                    _buildStepHeader("1b", "Upload Lecture Material"),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'docx', 'txt'],
                          withData: true,
                        );
                        if (result != null) setState(() => _contentFile = result.files.first);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _contentFile != null ? const Color(0xFFEEF2FF) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _contentFile != null ? const Color(0xFF4F46E5) : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(children: [
                          Icon(_contentFile != null ? Icons.check_circle : Icons.cloud_upload_outlined,
                              color: _contentFile != null ? const Color(0xFF4F46E5) : Colors.grey,
                              size: 36),
                          const SizedBox(height: 8),
                          Text(
                            _contentFile != null
                                ? _contentFile!.name
                                : 'Tap to upload lecture notes (PDF, DOCX, TXT)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _contentFile != null ? const Color(0xFF4F46E5) : Colors.grey,
                            ),
                          ),
                          if (_contentFile != null) ...[
                            const SizedBox(height: 4),
                            Text('Tap to replace', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  _buildStepHeader("2", "Question Type"),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTypeOptionCard(
                        label: "MCQ",
                        icon: Icons.list_alt,
                        subtitle: "Multiple choice",
                        isSelected: selectedTypeMode == 'MCQ',
                        onTap: () =>
                            setState(() => selectedTypeMode = 'MCQ'),
                      ),
                      const SizedBox(width: 8),
                      _buildTypeOptionCard(
                        label: "Essay",
                        icon: Icons.article_outlined,
                        subtitle: "Open answer",
                        isSelected: selectedTypeMode == 'Essay',
                        onTap: () =>
                            setState(() => selectedTypeMode = 'Essay'),
                      ),
                      const SizedBox(width: 8),
                      _buildTypeOptionCard(
                        label: "Mix",
                        icon: Icons.shuffle,
                        subtitle: "Random split",
                        isSelected: selectedTypeMode == 'Mix',
                        onTap: () =>
                            setState(() => selectedTypeMode = 'Mix'),
                      ),
                    ],
                  ),
                  if (selectedTypeMode == 'Mix') ...[
                    const SizedBox(height: 12),
                    Builder(builder: (ctx) {
                      final int total = int.tryParse(_questionsController.text) ?? selectedQuestions;
                      final int mcqCount = _mixDistribution(total)['MCQ'] ?? 0;
                      final int essayCount = _mixDistribution(total)['Essay'] ?? 0;
                      final int mcqPct = mcqPercentage.round();
                      final int essayPct = 100 - mcqPct;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE0E7FF)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.tune, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 10),
                              const Text("Mix Distribution", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937))),
                            ]),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Row(children: [
                                Expanded(
                                  flex: mcqPct,
                                  child: Container(
                                    height: 28,
                                    color: const Color(0xFF4F46E5),
                                    alignment: Alignment.center,
                                    child: Text("MCQ $mcqPct%", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                Expanded(
                                  flex: essayPct,
                                  child: Container(
                                    height: 28,
                                    color: const Color(0xFF7C3AED),
                                    alignment: Alignment.center,
                                    child: Text("Essay $essayPct%", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 12),
                            SliderTheme(
                              data: SliderTheme.of(ctx).copyWith(
                                activeTrackColor: const Color(0xFF4F46E5),
                                inactiveTrackColor: const Color(0xFF7C3AED),
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                overlayColor: const Color(0x224F46E5),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: mcqPercentage,
                                min: 10,
                                max: 90,
                                divisions: 8,
                                onChanged: (val) => setState(() => mcqPercentage = val),
                              ),
                            ),
                            Row(children: [
                              Expanded(child: _buildMixStatTile(Icons.list_alt, "MCQ", mcqCount, mcqPct, const Color(0xFF4F46E5), const Color(0xFFEEF2FF))),
                              const SizedBox(width: 12),
                              Expanded(child: _buildMixStatTile(Icons.article_outlined, "Essay", essayCount, essayPct, const Color(0xFF7C3AED), const Color(0xFFF5F3FF))),
                            ]),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 24),

                  _buildStepHeader("3", "Bloom's Level"),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedBlooms,
                    items: [
                      'Remember','Understand','Apply',
                      'Analyze','Evaluate','Create'
                    ]
                        .map((l) =>
                            DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => selectedBlooms = val!),
                    decoration: _inputDecoration(""),
                  ),
                  const SizedBox(height: 24),

                  _buildStepHeader("4", "Difficulty"),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () =>
                        setState(() => selectedDifficultyMode = 'All'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: selectedDifficultyMode == 'All'
                            ? const Color(0xFFEEF2FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedDifficultyMode == 'All'
                              ? const Color(0xFF4F46E5)
                              : Colors.grey.shade200,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: selectedDifficultyMode == 'All'
                                  ? const Color(0xFF4F46E5)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.layers,
                                color: selectedDifficultyMode == 'All'
                                    ? Colors.white
                                    : Colors.grey,
                                size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("All Levels",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: selectedDifficultyMode == 'All'
                                            ? const Color(0xFF4F46E5)
                                            : Colors.black87)),
                                const Text(
                                    "Easy + Medium + Hard randomly mixed",
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          if (selectedDifficultyMode == 'All')
                            const Icon(Icons.check_circle,
                                color: Color(0xFF4F46E5)),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _buildDifficultyOptionCard(
                        label: "Easy",
                        color: const Color(0xFF10B981),
                        bgColor: const Color(0xFFD1FAE5),
                        isSelected: selectedDifficultyMode == 'Easy',
                        onTap: () => setState(
                            () => selectedDifficultyMode = 'Easy'),
                      ),
                      const SizedBox(width: 8),
                      _buildDifficultyOptionCard(
                        label: "Medium",
                        color: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFEF3C7),
                        isSelected: selectedDifficultyMode == 'Medium',
                        onTap: () => setState(
                            () => selectedDifficultyMode = 'Medium'),
                      ),
                      const SizedBox(width: 8),
                      _buildDifficultyOptionCard(
                        label: "Hard",
                        color: const Color(0xFFEF4444),
                        bgColor: const Color(0xFFFFE4E6),
                        isSelected: selectedDifficultyMode == 'Hard',
                        onTap: () => setState(
                            () => selectedDifficultyMode = 'Hard'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildStepHeader("5", "Number of Questions"),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          final current =
                              int.tryParse(_questionsController.text) ?? 5;
                          if (current > 1) {
                            setState(() {
                              selectedQuestions = current - 1;
                              _questionsController.text =
                                  selectedQuestions.toString();
                            });
                          }
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        color: const Color(0xFF4F46E5),
                        iconSize: 32,
                      ),

                      Expanded(
                        child: TextField(
                          controller: _questionsController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 1 && parsed <= 50) {
                              setState(() => selectedQuestions = parsed);
                            }
                          },
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          final current =
                              int.tryParse(_questionsController.text) ?? 5;
                          if (current < 50) {
                            setState(() {
                              selectedQuestions = current + 1;
                              _questionsController.text =
                                  selectedQuestions.toString();
                            });
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        color: const Color(0xFF4F46E5),
                        iconSize: 32,
                      ),
                    ],
                  ),
                  Center(
                    child: Text("Enter 1–50 questions",
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12)),
                  ),

                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _handleGenerateExam,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Generate Exam ✨",
                          style: TextStyle(
                              color: Colors.white, fontSize: 16)),
                    ),
                  ),

                  if (generatedQuestions.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${generatedQuestions.length} Questions Generated",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        if (currentExamId != null)
                          ElevatedButton.icon(
                            onPressed: () => _downloadExamToDevice(currentExamId!),
                            icon: const Icon(Icons.file_download, size: 18),
                            label: const Text("Export"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                      ],
                    ),

                    // ── Exam Variations banner ─────────────────────────
                    if (currentExamId != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.copy_all_outlined, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Generate Exam Versions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            const Text('Create shuffled versions to minimise cheating', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ])),
                          isGeneratingVariations
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF4F46E5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  onPressed: _showVariationsDialog,
                                  child: const Text('Generate', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: generatedQuestions.length,
                      itemBuilder: (context, index) {
                        final q = generatedQuestions[index];
                        return _buildQuestionCard(q, index + 1);
                      },
                    ),
                    const SizedBox(height: 24),
                    if (currentExamId != null)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _downloadExamToDevice(currentExamId!),
                          icon: const Icon(Icons.download),
                          label: const Text("Export as Word Document",
                              style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final int total = int.tryParse(_questionsController.text) ?? selectedQuestions;
    final types = resolvedTypes;
    final difficulties = resolvedDifficulties;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text("Exam Summary",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            selectedTypeMode == 'Mix'
                ? "~$total Qs · MCQ ${mcqPercentage.round()}% / Essay ${(100 - mcqPercentage).round()}%"
                : selectedDifficultyMode == 'All'
                    ? "~$total questions · ${types.first} across Easy, Medium & Hard"
                    : "$total × ${types.first} · ${difficulties.first}",
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            "Bloom's: $selectedBlooms · Topic: ${_topicController.text.isEmpty ? '(not set)' : _topicController.text}",
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOptionCard({
    required String label,
    required IconData icon,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : Colors.grey.shade200,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : Colors.grey,
                    size: 28),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : Colors.black87)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center),
                if (isSelected) ...[
                  const SizedBox(height: 6),
                  const Icon(Icons.check_circle,
                      color: Color(0xFF4F46E5), size: 16),
                ]
              ],
            ),
          ),
        ),
      );

  Widget _buildDifficultyOptionCard({
    required String label,
    required Color color,
    required Color bgColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? bgColor : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade200,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : Colors.black54)),
                if (isSelected) ...[
                  const SizedBox(height: 4),
                  Icon(Icons.check_circle, color: color, size: 16),
                ]
              ],
            ),
          ),
        ),
      );

  Widget _buildQuestionCard(Map<String, dynamic> q, int number) {
    final List<dynamic>? options = q['options'];
    String correctAnswer = (q['correct_answer'] ?? '').toString();
    if (options != null && options.isNotEmpty) {
      final raw = q['correct_answer'];
      if (raw is int && raw >= 0 && raw < options.length) {
        correctAnswer = options[raw].toString();
      } else if (correctAnswer.length == 1) {
        final letter = correctAnswer.toUpperCase();
        final idx = letter.codeUnitAt(0) - 'A'.codeUnitAt(0);
        if (idx >= 0 && idx < options.length) correctAnswer = options[idx].toString();
      }
    }
    final String explanation = q['explanation'] ?? '';
    final String questionType = q['question_type'] ?? 'MCQ';
    final String questionDifficulty = q['difficulty'] ?? 'Medium';

    Color diffBg, diffText;
    switch (questionDifficulty.toLowerCase()) {
      case 'easy':
        diffBg = const Color(0xFFD1FAE5);
        diffText = const Color(0xFF065F46);
        break;
      case 'hard':
        diffBg = const Color(0xFFFFE4E6);
        diffText = const Color(0xFF9F1239);
        break;
      default:
        diffBg = const Color(0xFFFEF3C7);
        diffText = const Color(0xFFD97706);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF4F46E5),
            child: Text("$number",
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          title: Text(
            q['question_text'] ?? '',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937)),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                _buildBadge(questionDifficulty, diffBg, diffText),
                const SizedBox(width: 8),
                _buildBadge(questionType, const Color(0xFFEEF2FF),
                    const Color(0xFF4F46E5)),
              ],
            ),
          ),
          children: [
            if (options != null && options.isNotEmpty) ...[
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Options:",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7280))),
              ),
              const SizedBox(height: 8),
              ...options.map((opt) {
                final isCorrect = opt.toString() == correctAnswer;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCorrect
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isCorrect
                            ? const Color(0xFF10B981)
                            : Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(opt.toString(),
                            style: TextStyle(
                              color: isCorrect
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF374151),
                              fontWeight: isCorrect
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            )),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (options == null || options.isEmpty) ...[
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Model Answer:",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7280))),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Text(correctAnswer,
                    style: const TextStyle(color: Color(0xFF065F46))),
              ),
            ],
            if (explanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Color(0xFFD97706), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(explanation,
                          style: const TextStyle(
                              color: Color(0xFF92400E), fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMixStatTile(IconData icon, String label, int count, int pct, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          Text("$count questions · $pct%", style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _buildMixBadge(String type, String pct, String count, Color color) => const SizedBox();

  Widget _buildBadge(String label, Color bg, Color textColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  Widget _buildStepHeader(String s, String t) => Row(children: [
        CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF4F46E5),
            child: Text(s,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12))),
        const SizedBox(width: 8),
        Text(t,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold))
      ]);

  InputDecoration _inputDecoration(String h) => InputDecoration(
        hintText: h,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      );
}