import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

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
  bool isLoading = false;
  String? currentExamId;
  List<dynamic> generatedQuestions = [];
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _questionsController =
      TextEditingController(text: '5');

  List<String> get resolvedTypes {
    if (selectedTypeMode == 'Mix') return ['MCQ', 'Essay'];
    return [selectedTypeMode];
  }

  List<String> get resolvedDifficulties {
    if (selectedDifficultyMode == 'All') return ['Easy', 'Medium', 'Hard'];
    return [selectedDifficultyMode];
  }

  // ✅ Randomly distribute questions across combinations for Mix mode
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

    // ✅ Random distribution — not even split
    final rand = Random();
    int remaining = total;

    for (int i = 0; i < combos.length - 1; i++) {
      // Give each combo at least 1, randomly assign up to remaining-1
      final maxForThis = remaining - (combos.length - 1 - i);
      final assigned = maxForThis <= 1 ? 1 : (rand.nextInt(maxForThis - 1) + 1);
      distribution[combos[i]] = assigned;
      remaining -= assigned;
    }
    // Last combo gets whatever is left
    distribution[combos.last] = remaining;

    return distribution;
  }

  Future<void> _downloadExamToDevice(String examId) async {
    setState(() => isLoading = true);
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isWindows) {
        directory = Directory(
            '${Platform.environment['USERPROFILE']}\\Downloads');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      String savePath = "${directory!.path}/Profound_Exam_$examId.docx";
      Dio dio = Dio();
      await dio.download(
        'http://127.0.0.1:8000/exams/export-word/$examId',
        savePath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Exam saved to Downloads folder!"),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: "Open",
              textColor: Colors.white,
              onPressed: () => OpenFile.open(savePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleGenerateExam() async {
    print("=== GENERATE TAPPED ===");

    if (_topicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please enter a topic first!"),
            backgroundColor: Colors.red),
      );
      return;
    }

    // ✅ Parse manually entered number
    final int? parsed = int.tryParse(_questionsController.text);
    if (parsed == null || parsed < 1 || parsed > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please enter a valid number between 1 and 50"),
            backgroundColor: Colors.red),
      );
      return;
    }
    selectedQuestions = parsed;

    setState(() {
      isLoading = true;
      generatedQuestions = [];
      currentExamId = null;
    });

    try {
      final List<String> types = resolvedTypes;
      final List<String> difficulties = resolvedDifficulties;

      // ✅ Use random distribution for Mix, even split for single type
      final Map<String, int> distribution =
          _distributeQuestions(types, difficulties, selectedQuestions);

      print("Distribution: $distribution");

      List<dynamic> allQuestions = [];
      String? examId;

      for (String type in types) {
        for (String difficulty in difficulties) {
          final key = '$type|$difficulty';
          final int count = distribution[key] ?? 1;

          if (count == 0) continue;

          print("Requesting $count $type questions at $difficulty");

          final response = await http.post(
            Uri.parse('http://127.0.0.1:8000/exams/generate'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "topic": _topicController.text,
              "number_of_questions": count,
              "difficulty": difficulty,
              "blooms_level": selectedBlooms,
              "question_type": type,
            }),
          ).timeout(const Duration(seconds: 300));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            examId ??= data['exam_id'];
            allQuestions.addAll(data['questions']);
            print("Got ${data['questions'].length} questions for $key");
          } else {
            throw Exception("Server Error: ${response.statusCode} - ${response.body}");
          }
        }
      }

      // ✅ Final trim to exact count
      if (allQuestions.length > selectedQuestions) {
        allQuestions = allQuestions.sublist(0, selectedQuestions);
      }

      setState(() {
        currentExamId = examId;
        generatedQuestions = allQuestions;
      });

      print("Total questions displayed: ${allQuestions.length}");
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
                  _buildStepHeader("1", "Exam Topic"),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _topicController,
                    decoration: _inputDecoration("e.g., Data Structures"),
                  ),
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF4F46E5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shuffle,
                              color: Color(0xFF4F46E5), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "MCQ & Essay will be randomly distributed — not split evenly",
                              style: TextStyle(
                                  color: Color(0xFF4F46E5), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
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

                  // ✅ Number of questions with keyboard + counter
                  _buildStepHeader("5", "Number of Questions"),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Counter buttons
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

                      // ✅ Editable text field
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
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937)),
                        ),
                        if (currentExamId != null)
                          ElevatedButton.icon(
                            onPressed: () =>
                                _downloadExamToDevice(currentExamId!),
                            icon: const Icon(Icons.file_download, size: 18),
                            label: const Text("Export"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                      ],
                    ),
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
                ? "~$total questions · MCQ & Essay randomly distributed"
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
    final String correctAnswer = q['correct_answer'] ?? '';
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