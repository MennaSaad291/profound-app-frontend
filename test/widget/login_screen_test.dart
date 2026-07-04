// test/widget/login_screen_test.dart
//
// Widget tests for the LoginScreen.
// Verifies that key UI elements are rendered and basic validation works
// without making real HTTP calls.
//
// Run with: flutter test test/widget/login_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profound_app_frontend/features/auth/screens/login_screen.dart';

Widget _buildApp() {
  return const MaterialApp(
    home: LoginScreen(),
  );
}

void main() {
  group('LoginScreen — UI elements', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(_buildApp());

      expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
    });

    testWidgets('renders Login button', (tester) async {
      await tester.pumpWidget(_buildApp());

      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets('renders Sign Up navigation button', (tester) async {
      await tester.pumpWidget(_buildApp());

      expect(
        find.textContaining('University Credentials'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('email field accepts input', (tester) async {
      await tester.pumpWidget(_buildApp());

      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@university.edu');
      await tester.pump();

      expect(find.text('test@university.edu'), findsOneWidget);
    });

    testWidgets('password field accepts input', (tester) async {
      await tester.pumpWidget(_buildApp());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.last, 'SecurePass123');
      await tester.pump();

      // Password field obscures text — value won't be visible as plain text
      // but the field should still accept the input without crashing
    });

    testWidgets('does not crash on initial render', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      // No exception = pass
    });
  });
}
