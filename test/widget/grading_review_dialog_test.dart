// test/widget/grading_review_dialog_test.dart
//
// Widget tests for the GradingReviewDialog.
// Tests that the dialog renders AI score, feedback sections, and grade override field.
//
// Run with: flutter test test/widget/grading_review_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profound_app_frontend/features/grading/grading_review_dialog.dart';

/// Minimal submission map that GradingReviewDialog expects.
Map<String, dynamic> _submission({
  int aiGrade = 85,
  int? manualGrade,
  int plagiarism = 2,
  String summary = 'Student demonstrated good understanding.',
  List<String> strengths = const ['Clear explanation', 'Good structure'],
  List<String> improvements = const ['Needs more examples'],
  String recommendation = 'Review chapter 3.',
  String tone = 'formal',
}) {
  return {
    'student_name': 'Ahmed Mohamed',
    'ai_grade': aiGrade,
    'manual_grade': manualGrade,
    'plagiarism_score': plagiarism,
    'essay_content': 'This is the student essay content.',
    'status': manualGrade != null ? 'graded' : 'ready',
    'grade_report': {
      'summary': summary,
      'strengths': strengths,
      'areas_for_improvement': improvements,
      'error_categories': {
        'conceptual': 'Minor misunderstanding of recursion.',
        'structural': null,
        'language': null,
        'completeness': null,
      },
      'recommendation': recommendation,
      'feedback_tone': tone,
    },
  };
}

Widget _buildDialog(Map<String, dynamic> submission) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => GradingReviewDialog(
          submission: submission,
          onFinalize: (grade) async {},
        ),
      ),
    ),
  );
}

void main() {
  group('GradingReviewDialog — score display', () {
    testWidgets('shows student name in header', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission()));
      expect(find.text('Ahmed Mohamed'), findsOneWidget);
    });

    testWidgets('shows AI score', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission(aiGrade: 78)));
      expect(find.text('78%'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows plagiarism score', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission(plagiarism: 5)));
      expect(find.text('5%'), findsAtLeastNWidgets(1));
    });
  });

  group('GradingReviewDialog — feedback sections', () {
    testWidgets('shows Overall Assessment section', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission()));
      await tester.pump();
      expect(find.textContaining('Assessment'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows summary text', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission(
          summary: 'Student demonstrated good understanding.')));
      await tester.pump();
      // Scroll to make content visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pump();
      expect(
        find.textContaining('Student demonstrated'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('shows Strengths section when strengths are present', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission(
          strengths: ['Clear explanation'])));
      await tester.pump();
      expect(find.textContaining('Strength'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Areas for Improvement section', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission(
          improvements: ['More examples needed'])));
      await tester.pump();
      expect(find.textContaining('Improvement'), findsAtLeastNWidgets(1));
    });
  });

  group('GradingReviewDialog — grade override', () {
    testWidgets('shows Final Grade Adjustment section', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission()));
      await tester.pump();
      expect(find.textContaining('Grade'), findsAtLeastNWidgets(1));
    });

    testWidgets('pre-fills grade field with ai_grade when no manual override', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission(aiGrade: 90)));
      await tester.pump();
      expect(find.text('90'), findsAtLeastNWidgets(1));
    });

    testWidgets('pre-fills grade field with manual_grade when override exists', (tester) async {
      await tester.pumpWidget(_buildDialog(
          _submission(aiGrade: 70, manualGrade: 85)));
      await tester.pump();
      expect(find.text('85'), findsAtLeastNWidgets(1));
    });

    testWidgets('Finalize Grade button is present', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission()));
      await tester.pump();
      expect(find.textContaining('Finalize'), findsAtLeastNWidgets(1));
    });

    testWidgets('Cancel button is present', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission()));
      await tester.pump();
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('GradingReviewDialog — professor override banner', () {
    testWidgets('shows override banner when manual_grade is set', (tester) async {
      await tester.pumpWidget(_buildDialog(
          _submission(aiGrade: 60, manualGrade: 75)));
      await tester.pump();
      expect(find.textContaining('Override'), findsAtLeastNWidgets(1));
    });

    testWidgets('does not show override banner when no manual grade', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission(manualGrade: null)));
      await tester.pump();
      // "Professor Override" text should not appear
      expect(find.text('Professor Override'), findsNothing);
    });
  });

  group('GradingReviewDialog — plagiarism alert', () {
    testWidgets('shows plagiarism alert when score > 10', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission(plagiarism: 45)));
      await tester.pump();
      // Scroll to find the alert
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pump();
      expect(find.textContaining('similarity'), findsAtLeastNWidgets(1));
    });

    testWidgets('does not show plagiarism alert text for zero score', (tester) async {
      await tester.pumpWidget(_buildDialog(_submission(plagiarism: 0)));
      await tester.pump();
      // Zero plagiarism — should show "No plagiarism detected" not a warning
      expect(find.textContaining('No plagiarism detected'), findsOneWidget);
    });
  });
}
