import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        Text("Your university's comprehensive platform for academic excellence",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textGray500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textGray900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                Center(
                  child: Text("Get Started",
                      style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
                ),
                const SizedBox(height: 32),
                _buildLabel("Full Name"),
                _buildTextFormField(
                  controller: _nameController,
                  hint: "John Doe",
                  validator: (value) => (value == null || value.trim().split(' ').length < 2) ? "Please enter your full name" : null,
                ),
                const SizedBox(height: 20),
                _buildLabel("University Email"),
                _buildTextFormField(
                  controller: _emailController,
                  hint: "you@university.edu",
                  validator: (value) {
                    if (value == null || !value.contains('.edu')) return "A valid .edu email is required";
                    return null;
                  },
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
    if (value == null || value.isEmpty) return "Password is required";

    List<String> errors = [];

    if (value.length < 8) {
      errors.add("• At least 8 characters");
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      errors.add("• At least one uppercase letter");
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      errors.add("• At least one lowercase letter");
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      errors.add("• At least one number");
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add("• At least one special character");
    }

    if (errors.isNotEmpty) {
      return "Password must include:\n${errors.join('\n')}";
    }

    return null;
  },
),
                const SizedBox(height: 40),
                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Success Logic
                      }
                    },
                    child: const Text("Create Account", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                // Policy Text
                const Center(
                  child: Text(
                    "By signing up, you agree to our data protection policy.",
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          AppColors.textGray500,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 30),               
                ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.inter(color: AppColors.textGray700, fontWeight: FontWeight.w500, fontSize: 14)),
    );
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderGray)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
      ),
    );
  }
}