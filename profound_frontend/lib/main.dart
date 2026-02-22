import 'package:flutter/material.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/profile_screen.dart';
import 'features/courses/screens/courses_list_screen.dart';
import 'features/courses/screens/course_details_screen.dart';
import 'features/dashboard/screens/professor_dashboard.dart';
import 'features/layout/main_layout.dart';

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
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpForm(),
        '/profile': (context) => const MainLayout(child: ProfessorProfileScreen()),
        '/courses': (context) => const MainLayout(child: CoursesModuleScreen()),
        '/course_details': (context) => const MainLayout(child: CourseDetailsDashboard()),
        '/dashboard': (context) => const MainLayout(child: ProfessorDashboard()),
      },
    );
  }
}