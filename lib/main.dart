import 'package:flutter/material.dart';
import 'features/auth/screens/login_screen.dart'; 

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
      home: LoginScreen(), 
    );
  }
}