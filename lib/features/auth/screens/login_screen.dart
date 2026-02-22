import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_colors.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  Future<void> _loginUser() async {
    setState(() => _isLoading = true);
    
    final url = Uri.parse('http://localhost:8000/login'); 

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Welcome back, ${data['user']['name']}!"),
            backgroundColor: Colors.green,
          ),
        );

        final userData = {
          'id': data['user']['id'],
          'name': data['user']['name'],
        };

        Navigator.pushReplacementNamed(
          context, 
          '/dashboard', 
          arguments: userData, 
        );

      } else if (response.statusCode == 422) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid format. Please use a valid university email (e.g. name@university.edu)"),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        final String errorMessage = data['detail'] ?? "Login failed";
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage), 
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection failed")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Center(child: _buildProfoundHeader()),
                  const SizedBox(height: 32),
                  Center(
                    child: Text("Welcome Back to Profound",
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
                  ),
                  const SizedBox(height: 28),
                  
                  _buildLabel("University Email or ID"),
                  _buildTextFormField(
                    controller: _emailController,
                    hint: "you@university.edu",
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Please enter your email";
                      if (!value.contains('@')) return "Enter a valid email address";
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildLabel("Password"),
                  _buildTextFormField(
                    controller: _passwordController,
                    hint: "Enter your password",
                    obscure: !_showPassword,
                    suffix: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? "Password is required" : null,
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent, 
                        shadowColor: Colors.transparent,
                      ),
                      onPressed: _isLoading ? null : () {
                        if (_formKey.currentState!.validate()) {
                          _loginUser();
                        }
                      },
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Login", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryPurple, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpForm())),
                      child: const Text(
                        "Sign up with University Credentials",
                        style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfoundHeader() {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRect(
              child: Align(
                alignment: Alignment.center,
                widthFactor: 0.65,
                child: Image.asset(
                  'assets/images/logo.jpeg',
                  height: 70,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.book, color: Colors.amber, size: 48),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text.rich(
              TextSpan(
                children: const [
                  TextSpan(text: "Prof", style: TextStyle(color: AppColors.darkPurple)),
                  TextSpan(text: "ound", style: TextStyle(color: AppColors.brandAmber)),
                ],
              ),
              style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.bold, height: 1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            "Your university's comprehensive platform for academic excellence",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textGray500, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.inter(color: AppColors.textGray700, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTextFormField({required String hint, required TextEditingController controller, bool obscure = false, Widget? suffix, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderGray)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
      ),
    );
  }
}