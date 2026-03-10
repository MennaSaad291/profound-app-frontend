import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_colors.dart';

class SystemSettingsScreen extends StatefulWidget {
  final int userId;
  const SystemSettingsScreen({super.key, this.userId = 0});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  String _activeMenu = 'rubrics';
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _twoFactorEnabled = false;
  bool _isChangingPassword = false;

  // Notification toggles
  bool _emailNotif = true;
  bool _gradingNotif = true;
  bool _deadlineNotif = true;
  bool _atRiskNotif = true;

  // AI Config
  bool _detailedFeedback = true;
  String _feedbackTone = 'Formal';
  double _gradingSensitivity = 3;

  final List<Map<String, dynamic>> _rubrics = [
    {'id': 1, 'name': 'Essay Rubric - IS 405', 'course': 'IS 405', 'criteria': 5, 'lastModified': '2025-11-28'},
    {'id': 2, 'name': 'Technical Report Rubric', 'course': 'CS 401', 'criteria': 6, 'lastModified': '2025-11-25'},
    {'id': 3, 'name': 'Research Paper Rubric', 'course': 'CS 501', 'criteria': 8, 'lastModified': '2025-11-20'},
    {'id': 4, 'name': 'Lab Assignment Rubric', 'course': 'CS 301', 'criteria': 4, 'lastModified': '2025-11-15'},
  ];

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
    {'id': 'rubrics', 'icon': Icons.description_outlined, 'label': 'Grading & Rubrics'},
    {'id': 'notifications', 'icon': Icons.notifications_outlined, 'label': 'Notifications'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/profile/${widget.userId}'),
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
    // Ask for password confirmation before saving
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
              const SizedBox(height: 16),
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
                          Uri.parse('http://localhost:8000/verify-password'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({
                            'user_id': widget.userId,
                            'password': passwordController.text.trim(),
                          }),
                        );
                        if (response.statusCode == 200) {
                          // Password correct — now save profile
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
        Uri.parse('http://localhost:8000/profile/${widget.userId}'),
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

    // Basic client-side validation
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
        Uri.parse('http://localhost:8000/change-password'),
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
        // Show the error message from the backend (e.g. "Current password is incorrect")
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

  // ─────────────────────────────────────────────────────────────────────────

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
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildMenuGrid(),
                    const SizedBox(height: 16),
                    _buildContent(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 80,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6B21A8), Color(0xFF9333EA), Color(0xFFD97706)],
            ),
          ),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('System Settings',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Configure your preferences',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.2,
        children: _menuItems.map((item) {
          final isActive = _activeMenu == item['id'];
          return GestureDetector(
            onTap: () => setState(() => _activeMenu = item['id']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
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
      case 'rubrics': return _buildRubricsSection();
      case 'notifications': return _buildNotificationsSection();
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
          const SizedBox(height: 20),
          _buildPrimaryButton('Save Changes', _updateProfile),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      children: [
        // Data Compliance
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  Text('Data Compliance & Privacy',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1E3A8A))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Profound complies with institutional data protection policies and international standards (GDPR, FERPA). All student data is encrypted and stored securely.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E40AF), height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Change Password Card
        _buildCard(
          icon: Icons.lock_outline,
          title: 'Change Password',
          child: Column(
            children: [
              // Current Password
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

              // New Password
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
              const SizedBox(height: 20),

              // Update Password Button
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
        const SizedBox(height: 14),

        // Two Factor Auth
        _buildCard(
          icon: Icons.security,
          title: 'Two-Factor Authentication',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enable 2FA',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Add an extra layer of security',
                        style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: _twoFactorEnabled,
                onChanged: (v) => setState(() => _twoFactorEnabled = v),
                activeThumbColor: AppColors.primaryPurple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRubricsSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Grading Rubrics',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('${_rubrics.length} rubrics configured',
                      style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: Text('New', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._rubrics.map((rubric) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rubric['name'],
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Text('Course: ${rubric['course']}',
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                Text('Criteria: ${rubric['criteria']}',
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                Text('Last Modified: ${rubric['lastModified']}',
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _rubricActionBtn('Edit', Icons.edit_outlined, const Color(0xFF7C3AED), const Color(0xFFFAF5FF))),
                    const SizedBox(width: 8),
                    Expanded(child: _rubricActionBtn('Duplicate', Icons.copy_outlined, const Color(0xFF1D4ED8), const Color(0xFFEFF6FF))),
                    const SizedBox(width: 8),
                    Expanded(child: _rubricActionBtn('Delete', Icons.delete_outline, const Color(0xFFB91C1C), const Color(0xFFFEF2F2))),
                  ],
                ),
              ],
            ),
          ),
        )),
        const SizedBox(height: 14),
        _buildCard(
          icon: Icons.settings_outlined,
          title: 'AI Model Configuration',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Feedback Tone', style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _feedbackTone,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
                ),
                items: ['Formal', 'Casual', 'Encouraging', 'Direct']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _feedbackTone = v!),
              ),
              const SizedBox(height: 16),
              Text('Grading Sensitivity', style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13)),
              Row(
                children: [
                  Text('Lenient', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                  Expanded(
                    child: Slider(
                      value: _gradingSensitivity,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: AppColors.primaryPurple,
                      onChanged: (v) => setState(() => _gradingSensitivity = v),
                    ),
                  ),
                  Text('Strict', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enable Detailed Feedback',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Provide comprehensive comments',
                            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                      ],
                    ),
                    Switch(
                      value: _detailedFeedback,
                      onChanged: (v) => setState(() => _detailedFeedback = v),
                      activeThumbColor: AppColors.primaryPurple,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildPrimaryButton('Save Configuration', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Configuration saved!'), backgroundColor: Colors.green),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return _buildCard(
      icon: Icons.notifications_outlined,
      title: 'Notification Preferences',
      child: Column(
        children: [
          _notifTile('Email Notifications', 'Receive updates via email', _emailNotif, (v) => setState(() => _emailNotif = v)),
          const SizedBox(height: 10),
          _notifTile('Grading Completion', 'When AI grading finishes', _gradingNotif, (v) => setState(() => _gradingNotif = v)),
          const SizedBox(height: 10),
          _notifTile('Deadline Reminders', 'Upcoming assignment deadlines', _deadlineNotif, (v) => setState(() => _deadlineNotif = v)),
          const SizedBox(height: 10),
          _notifTile('At-Risk Student Alerts', 'Predictive analytics warnings', _atRiskNotif, (v) => setState(() => _atRiskNotif = v)),
          const SizedBox(height: 20),
          _buildPrimaryButton('Save Preferences', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Preferences saved!'), backgroundColor: Colors.green),
            );
          }),
        ],
      ),
    );
  }

  Widget _notifTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(subtitle, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
            ],
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primaryPurple),
        ],
      ),
    );
  }

  Widget _buildCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 16),
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

  Widget _rubricActionBtn(String label, IconData icon, Color color, Color bg) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}