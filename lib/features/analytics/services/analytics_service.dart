import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
// Conditional import: web uses dart:html, other platforms use a stub
import 'analytics_service_export_stub.dart'
    if (dart.library.html) 'analytics_service_export_web.dart';

class AnalyticsService {
  static const String baseUrl = "http://127.0.0.1:8000";

  static Future<List<dynamic>> getCourses({http.Client? client}) async {
    final c = client ?? http.Client();
    final response = await c.get(Uri.parse('$baseUrl/analysis/courses'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load courses");
    }
  }

  static Future<Map<String, dynamic>> getAnalytics({
    int? courseId,
    required String semester,
    int? days,
    String? fromDate,
    String? toDate,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    final response = await c.post(
      Uri.parse('$baseUrl/analysis/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        if (courseId != null) "course_id": courseId,
        if (semester != "All Semesters") "semester": semester,
        if (days != null) "days": days,
        if (fromDate != null) "from_date": fromDate,
        if (toDate != null) "to_date": toDate,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load analytics");
    }
  }

  static Future<String> uploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true,
      );

      if (result == null) return "cancelled";

      final fileBytes = result.files.single.bytes;
      final fileName = result.files.single.name;

      if (fileBytes == null) return "error: empty file";

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-performance'),
      );

      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        final decoded = jsonDecode(responseBody);

        return "error: ${decoded['message']}";
      }
    } catch (e) {
      return "error: $e";
    }
  }

  static Future<List<dynamic>> getBenchmarks(int courseId,
      {http.Client? client}) async {
    final c = client ?? http.Client();
    final response = await c.get(
      Uri.parse('$baseUrl/analysis/benchmarks?course_id=$courseId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load benchmarks");
    }
  }

  static Future<void> exportReport({
    required Map<String, bool> config,
    required String format,
    int? courseId,
    String? semester,
    int? days,
    String? fromDate,
    String? toDate,
  }) async {
    final url = Uri.parse("$baseUrl/analysis/export");

    final response = await http.post(
      url.replace(
        queryParameters: {
          if (courseId != null) "course_id": courseId.toString(),
          if (semester != null) "semester": semester,
          if (days != null) "days": days.toString(),
          if (fromDate != null) "from_date": fromDate,
          if (toDate != null) "to_date": toDate,
        },
      ),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "include_pii": config['includeStudentPII'] ?? false,
        "include_benchmarks": config['includeDepartmentBenchmarks'] ?? false,
        "error_analysis_detail": config['includeErrorAnalysis'] ?? false,
        "predictive_analytics": config['includePredictiveMetrics'] ?? false,
        "attendance_data": config['includeAttendanceData'] ?? false,
        "grade_distribution": config['includeGradeDistribution'] ?? false,
        "include_at_risk": config['includeAtRiskStudents'] ?? false,
        "export_format": format,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Export failed");
    }

    final bytes = response.bodyBytes;
    final fileName =
        "analytics_report_${DateTime.now().millisecondsSinceEpoch}.${format == 'excel' ? 'xlsx' : 'pdf'}";

    // Platform-conditional download (web: dart:html, other: stub/share)
    downloadBytes(bytes.toList(), fileName);
  }
}