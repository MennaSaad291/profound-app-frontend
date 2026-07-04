// test/unit/analytics_service_test.dart
//
// Unit tests for AnalyticsService HTTP methods using a mock HTTP client.
// These tests verify request construction and response parsing.
//
// Run with: flutter test test/unit/analytics_service_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// ── Inline minimal version of AnalyticsService for testing ───────────────────
// We re-implement just the HTTP-layer logic here to avoid importing
// dart:html (web-only) which would prevent VM test execution.

const _baseUrl = 'http://127.0.0.1:8000';

Future<List<dynamic>> testGetCourses(http.Client client) async {
  final response = await client.get(Uri.parse('$_baseUrl/analysis/courses'));
  if (response.statusCode == 200) return jsonDecode(response.body);
  throw Exception('Failed to load courses');
}

Future<Map<String, dynamic>> testGetAnalytics({
  required http.Client client,
  int? courseId,
  String semester = 'All Semesters',
  int? days,
}) async {
  final response = await client.post(
    Uri.parse('$_baseUrl/analysis/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      if (courseId != null) 'course_id': courseId,
      if (semester != 'All Semesters') 'semester': semester,
      if (days != null) 'days': days,
    }),
  );
  if (response.statusCode == 200) return jsonDecode(response.body);
  throw Exception('Failed to load analytics');
}

Future<List<dynamic>> testGetBenchmarks(http.Client client, int courseId) async {
  final response = await client.get(
    Uri.parse('$_baseUrl/analysis/benchmarks?course_id=$courseId'),
  );
  if (response.statusCode == 200) return jsonDecode(response.body);
  throw Exception('Failed to load benchmarks');
}

// ── Helpers ───────────────────────────────────────────────────────────────────

http.Client mockOk(String body) => MockClient(
    (req) async => http.Response(body, 200,
        headers: {'content-type': 'application/json'}));

http.Client mockError(int code) => MockClient(
    (req) async => http.Response('error', code,
        headers: {'content-type': 'application/json'}));

http.Client capturingClient(String body, void Function(http.Request) onReq) =>
    MockClient((req) async {
      onReq(req);
      return http.Response(body, 200,
          headers: {'content-type': 'application/json'});
    });

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('getCourses', () {
    test('returns list of courses on 200', () async {
      final body = jsonEncode([
        {'id': 1, 'code': 'CS101', 'name': 'Intro CS', 'display': 'CS101 - Intro CS'}
      ]);
      final result = await testGetCourses(mockOk(body));
      expect(result, isA<List>());
      expect(result.length, 1);
      expect(result[0]['code'], 'CS101');
    });

    test('throws on non-200', () async {
      expect(() => testGetCourses(mockError(500)), throwsException);
    });

    test('returns empty list when server returns []', () async {
      final result = await testGetCourses(mockOk('[]'));
      expect(result, isEmpty);
    });
  });

  group('getAnalytics', () {
    final samplePayload = jsonEncode({
      'performanceDistribution': {'Excellent (90-100)': 5},
      'correlation': {'stats': {}, 'points': []},
      'prediction': {'chart': []},
      'errorAnalysis': [],
    });

    test('returns analytics map on 200', () async {
      final result = await testGetAnalytics(
          client: mockOk(samplePayload), semester: 'All Semesters');
      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('performanceDistribution'), isTrue);
      expect(result.containsKey('errorAnalysis'), isTrue);
    });

    test('sends course_id in body when provided', () async {
      http.Request? captured;
      await testGetAnalytics(
        client: capturingClient(samplePayload, (req) => captured = req),
        courseId: 28,
        semester: 'All Semesters',
      );
      final body = jsonDecode(captured!.body);
      expect(body['course_id'], 28);
    });

    test('omits course_id when null', () async {
      http.Request? captured;
      await testGetAnalytics(
        client: capturingClient(samplePayload, (req) => captured = req),
        semester: 'All Semesters',
      );
      final body = jsonDecode(captured!.body);
      expect(body.containsKey('course_id'), isFalse);
    });

    test('omits semester when All Semesters', () async {
      http.Request? captured;
      await testGetAnalytics(
        client: capturingClient(samplePayload, (req) => captured = req),
        semester: 'All Semesters',
      );
      final body = jsonDecode(captured!.body);
      expect(body.containsKey('semester'), isFalse);
    });

    test('includes semester when not All Semesters', () async {
      http.Request? captured;
      await testGetAnalytics(
        client: capturingClient(samplePayload, (req) => captured = req),
        semester: 'Fall 2025',
      );
      final body = jsonDecode(captured!.body);
      expect(body['semester'], 'Fall 2025');
    });

    test('includes days when provided', () async {
      http.Request? captured;
      await testGetAnalytics(
        client: capturingClient(samplePayload, (req) => captured = req),
        semester: 'All Semesters',
        days: 30,
      );
      final body = jsonDecode(captured!.body);
      expect(body['days'], 30);
    });

    test('throws on non-200', () async {
      expect(
        () => testGetAnalytics(
            client: mockError(500), semester: 'All Semesters'),
        throwsException,
      );
    });
  });

  group('getBenchmarks', () {
    test('returns list on 200', () async {
      final body = jsonEncode([
        {'metric': 'Average Grade', 'yourCourse': 82.0,
         'department': 76.0, 'difference': '+6.0'}
      ]);
      final result = await testGetBenchmarks(mockOk(body), 28);
      expect(result, isA<List>());
      expect(result[0]['metric'], 'Average Grade');
    });

    test('sends correct course_id in URL', () async {
      http.Request? captured;
      await testGetBenchmarks(
        capturingClient('[]', (req) => captured = req),
        42,
      );
      expect(captured!.url.queryParameters['course_id'], '42');
    });

    test('throws on non-200', () async {
      expect(
        () => testGetBenchmarks(mockError(404), 28),
        throwsException,
      );
    });

    test('returns empty list when no benchmarks', () async {
      final result = await testGetBenchmarks(mockOk('[]'), 99);
      expect(result, isEmpty);
    });
  });
}
