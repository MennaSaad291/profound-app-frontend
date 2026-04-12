import 'package:flutter/material.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/profile_screen.dart';
import 'features/courses/screens/courses_list_screen.dart';
import 'features/courses/screens/course_details_screen.dart';
import 'features/courses/screens/ai_lecture_screen.dart';
import 'features/dashboard/screens/professor_dashboard.dart';
import 'features/layout/main_layout.dart';
import 'features/grading/ai_grading_module.dart';
import 'features/analytics/full_analytics_reports_module.dart';
import 'features/research/screens/research_organizer_screen.dart';
import 'features/settings/screens/system_settings_screen.dart';

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
        '/profile': (context) => const MainLayout(child: ProfessorProfileScreen()),
        '/courses': (context) => const MainLayout(child: CoursesListScreen()),
        '/course_details': (context) => const MainLayout(child: CourseDetailsDashboard()),
        '/dashboard': (context) => const MainLayout(child: ProfessorDashboard()),
        '/grading': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          int assignmentId = 0;

          if (args is Map) {
            assignmentId = (args['assignment_id'] ?? 0) as int;
          }

          return AIGradingModule(
            onBack: () => Navigator.pop(context),
            assignmentId: assignmentId,
          );
        },
        // '/analytics': (context) => FullAnalyticsReportsModule(onBack: () => Navigator.pop(context)),
        '/research': (context) => const ResearchOrganizerScreen(),
        '/settings': (context) {
          // Extract userId from route arguments passed by the sidebar
          final args = ModalRoute.of(context)?.settings.arguments;
          int userId = 0;
          if (args is Map) {
            userId = (args['id'] ?? args['user_id'] ?? 0) as int;
          }
          return SystemSettingsScreen(userId: userId);
        },
        '/generate_lecture': (context) => const MainLayout(child: AILectureScreen()),
      },
      home: const LoginScreen(),

    );
  }
}