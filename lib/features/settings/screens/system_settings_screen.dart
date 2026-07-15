import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_colors.dart';
import 'package:profound_app_frontend/core/constants/api_constants.dart';

class SystemSettingsScreen extends StatefulWidget {
  final int userId;
  const SystemSettingsScreen({super.key, this.userId = 0});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  String _activeMenu = 'account';
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _isChangingPassword = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _deptController = TextEditingController();
  final _titleController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoadingProfile = true;

  final List<Map<String, dynamic>> _menuItems = [
    {'id': 'account', 'icon': Icons.person_outline, 'label': 'Account & Profile'},
    {'id': 'security', 'icon': Icons.lock_outline, 'label': 'Security & Privacy'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/profile/${widget.userId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _deptController.text = data['department'] ?? '';
          _titleController.text = data['bio'] ?? '';
          _isLoadingProfile = false;
        });
      } else {
        setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      setState(() => _isLoadingProfile = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _deptController.dispose();
    _titleController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty || _deptController.text.trim().isEmpty) {
      _showSnack('Name and department cannot be empty', isError: true);
      return;
    }
    final confirmed = await _showPasswordConfirmDialog();
    if (!confirmed) return;
  }

  Future<bool> _showPasswordConfirmDialog() async {
    final passwordController = TextEditingController();
    bool showPw = false;
    bool isVerifying = false;
    String? errorText;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_outline, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Text('Confirm Identity',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter your password to save changes',
                  style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: !showPw,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: errorText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
                  suffixIcon: IconButton(
                    icon: Icon(showPw ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setDialogState(() => showPw = !showPw),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[600])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isVerifying
                  ? null
                  : () async {
                      if (passwordController.text.trim().isEmpty) {
                        setDialogState(() => errorText = 'Please enter your password');
                        return;
                      }
                      setDialogState(() { isVerifying = true; errorText = null; });
                      try {
                        final response = await http.post(
                          Uri.parse('${ApiConstants.baseUrl}/verify-password'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({
                            'user_id': widget.userId,
                            'password': passwordController.text.trim(),
                          }),
                        );
                        if (response.statusCode == 200) {
                          Navigator.pop(context, false); // close dialog
                          await _saveProfile();
                        } else {
                          setDialogState(() {
                            errorText = 'Incorrect password';
                            isVerifying = false;
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          errorText = 'Connection error';
                          isVerifying = false;
                        });
                      }
                    },
              child: isVerifying
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Confirm', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/profile/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': _nameController.text.trim(),
          'bio': _titleController.text.trim(),
          'department': _deptController.text.trim(),
        }),
      );
      if (response.statusCode == 200) {
        _showSnack('Profile updated successfully!');
      } else {
        final body = jsonDecode(response.body);
        _showSnack(body['detail'] ?? 'Failed to update profile', isError: true);
      }
    } catch (e) {
      _showSnack('Connection error. Please try again.', isError: true);
    } finally {
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final currentPw = _currentPasswordController.text.trim();
    final newPw = _newPasswordController.text.trim();

    if (currentPw.isEmpty || newPw.isEmpty) {
      _showSnack('Please fill in both password fields', isError: true);
      return;
    }
    if (newPw.length < 6) {
      _showSnack('New password must be at least 6 characters', isError: true);
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'current_password': currentPw,
          'new_password': newPw,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _showSnack('Password updated successfully!');
      } else {
        _showSnack(body['detail'] ?? 'Failed to update password', isError: true);
      }
    } catch (e) {
      _showSnack('Connection error. Please try again.', isError: true);
    } finally {
      setState(() => _isChangingPassword = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.green,
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E5F5), Colors.white, Color(0xFFFFF8E1)],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildMenuGrid(),
                    const SizedBox(height: 10),
                    _buildContent(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 3.8,
        children: _menuItems.map((item) {
          final isActive = _activeMenu == item['id'];
          return GestureDetector(
            onTap: () => setState(() => _activeMenu = item['id']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)])
                    : null,
                color: isActive ? null : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                boxShadow: isActive
                    ? [BoxShadow(color: AppColors.primaryPurple.withOpacity(0.3), blurRadius: 6)]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(item['icon'] as IconData,
                      color: isActive ? Colors.white : Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item['label'],
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isActive ? Colors.white : Colors.grey[700],
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeMenu) {
      case 'account': return _buildAccountSection();
      case 'security': return _buildSecuritySection();
      default: return const SizedBox();
    }
  }

  Widget _buildAccountSection() {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }
    return _buildCard(
      icon: Icons.person_outline,
      title: 'Profile Information',
      child: Column(
        children: [
          _buildTextField('Full Name', _nameController),
          const SizedBox(height: 12),
          _buildTextField('Email Address', _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _buildTextField('Department', _deptController),
          const SizedBox(height: 12),
          _buildTextField('Title', _titleController),
          const SizedBox(height: 10),
          _buildPrimaryButton('Save Changes', _updateProfile),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      children: [
        _buildCard(
          icon: Icons.lock_outline,
          title: 'Change Password',
          child: Column(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Password',
                      style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: !_showCurrentPassword,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
                      suffixIcon: IconButton(
                        icon: Icon(_showCurrentPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Password',
                      style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: !_showNewPassword,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
                      suffixIcon: IconButton(
                        icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isChangingPassword ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    disabledBackgroundColor: AppColors.primaryPurple.withOpacity(0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isChangingPassword
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Update Password',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
