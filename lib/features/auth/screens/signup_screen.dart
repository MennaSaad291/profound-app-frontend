import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_colors.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});
  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  Future<void> _registerUser() async {
    final url = Uri.parse('http://localhost:8000/register');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "full_name": _nameController.text.trim(),
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account created!")));
        Navigator.pop(context);
      } else {
        final error = jsonDecode(response.body)['detail'];
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection failed.")));
    }
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
                child: Image.asset('assets/images/logo.jpeg', height: 70),
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
              style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text("Your university's comprehensive platform for academic excellence",
            textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textGray500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _buildProfoundHeader()),
                const SizedBox(height: 32),
                _buildLabel("Full Name"),
                _buildTextFormField(
                  controller: _nameController,
                  hint: "John Doe",
                  validator: (value) => (value == null || value.trim().split(' ').length < 2) ? "Full name required" : null,
                ),
                const SizedBox(height: 20),
                _buildLabel("University Email"),
                _buildTextFormField(
                  controller: _emailController,
                  hint: "you@university.edu",
                  validator: (value) => (value == null || !value.contains('.edu')) ? "Valid .edu email required" : null,
                ),
                const SizedBox(height: 20),
                _buildLabel("Choose Password"),
                _buildTextFormField(
                  controller: _passwordController,
                  hint: "Create a strong password",
                  obscure: !_showPassword,
                  suffix: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Password required";
                    List<String> errors = [];
                    if (value.length < 8) errors.add("• Min 8 characters");
                    if (!value.contains(RegExp(r'[A-Z]'))) errors.add("• One uppercase letter");
                    if (!value.contains(RegExp(r'[a-z]'))) errors.add("• One lowercase letter");
                    if (!value.contains(RegExp(r'[0-9]'))) errors.add("• One number");
                    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) errors.add("• One special character");
                    return errors.isNotEmpty ? "Password must include:\n${errors.join('\n')}" : null;
                  },
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () { if (_formKey.currentState!.validate()) _registerUser(); },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
                    child: const Text("Create Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: GoogleFonts.inter(fontSize: 14)));
  }

  Widget _buildTextFormField({required String hint, required TextEditingController controller, bool obscure = false, Widget? suffix, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}