import 'package:flutter/material.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/profile_screen.dart';
import 'features/courses/courses_list_screen.dart';
import 'features/courses/screens/course_details_screen.dart';

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
        '/profile': (context) => const ProfessorProfileScreen(),
        '/courses': (context) => const CoursesModuleScreen(),
        '/course_details': (context) => const CourseDetailsDashboard(),
      },
    );
  }
}