import 'package:flutter/material.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/profile_screen.dart';
import 'features/courses/courses_list_screen.dart';
import 'features/courses/screens/course_details_screen.dart';
import 'features/grading/ai_grading_module.dart';
import 'features/analytics/full_analytics_reports_module.dart';

void main() {
  runApp(const ProfoundApp());
}

class ProfoundApp extends StatelessWidget {
  const ProfoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profound',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A)),
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpForm(),
        '/profile': (context) => const ProfessorProfileScreen(),
        '/courses': (context) => const CoursesModuleScreen(),
        '/course_details': (context) => const CourseDetailsDashboard(),
        '/grading_module': (context) =>
            AIGradingModule(onBack: () => Navigator.pop(context)),
        '/analytics': (context) =>
            FullAnalyticsReportsModule(onBack: () => Navigator.pop(context)),
      },
      home: LoginScreen(),
    );
  }
}
