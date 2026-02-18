import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Title
                Text("Profound", 
                  style: GoogleFonts.poppins(
                    fontSize: 48, 
                    fontWeight: FontWeight.bold, 
                    color: AppColors.textWhite,
                    letterSpacing: 1.5,
                  )
                ),
                Text("Your university's comprehensive platform for academic excellence", 
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.accentTeal, fontWeight: FontWeight.w300)
                ),
                const SizedBox(height: 60),

                // Email Input
                _buildInputLabel("University Email"),
                const SizedBox(height: 8),
                TextFormField(
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(Icons.email_outlined, "Enter your email"),
                  validator: (value) => (value == null || !value.contains('@')) ? "Invalid email" : null,
                ),
                const SizedBox(height: 24),

                // Password Input
                _buildInputLabel("Password"),
                const SizedBox(height: 8),
                TextFormField(
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    Icons.lock_outline, 
                    "Enter password",
                    suffix: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textGrey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    )
                  ),
                  validator: (value) => value!.length < 6 ? "Password too short" : null,
                ),
                
                const SizedBox(height: 40),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) { /* Handle Login */ }
                    },
                    child: Text("Login", 
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen())),
                  child: RichText(
                    text: TextSpan(
                      text: "New here? ",
                      style: GoogleFonts.poppins(color: AppColors.textGrey),
                      children: const [
                        TextSpan(text: "Create Account", style: TextStyle(color: AppColors.accentTeal, fontWeight: FontWeight.bold))
                      ]
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label, style: GoogleFonts.poppins(color: AppColors.textWhite, fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }

  InputDecoration _inputDecoration(IconData icon, String hint, {Widget? suffix}) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.fieldFill,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.accentTeal),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.accentTeal)),
    );
  }
}