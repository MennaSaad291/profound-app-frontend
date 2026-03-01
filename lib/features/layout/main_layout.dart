import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String title;

  const MainLayout({super.key, required this.child, this.title = "Profound"});

  @override
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    return Scaffold(
      drawer: _buildSidebar(context, currentRoute),
      appBar: AppBar(
        leadingWidth: 90,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Navigator.of(context).canPop())
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            Builder(
              builder: (innerContext) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(innerContext).openDrawer(),
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7E22CE), Color(0xFF9333EA), Color(0xFFD97706)],
            ),
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 255, 255, 255),
                shape: BoxShape.circle,
              ),
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                backgroundImage: AssetImage('assets/images/logo.jpeg'),
              ),
            ),
            const SizedBox(width: 10),
            Text.rich(
              TextSpan(
                children: const [
                  TextSpan(text: "Prof", style: TextStyle(color: Colors.white)),
                  TextSpan(text: "ound", style: TextStyle(color: Color(0xFFD97706))),
                ],
              ),
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: child,
    );
  }

  Widget _buildSidebar(BuildContext context, String? currentRoute) {
    return Drawer(
      width: 280,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage('assets/images/logo.jpeg'),
                ),
                const SizedBox(width: 12),
                Text.rich(
                  TextSpan(
                    children: const [
                      TextSpan(text: "Prof", style: TextStyle(color: Color(0xFF7E22CE))),
                      TextSpan(text: "ound", style: TextStyle(color: Color(0xFFD97706))),
                    ],
                  ),
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          _navItem(context, Icons.grid_view_rounded, "Dashboard", '/dashboard', currentRoute == '/dashboard'),
          _navItem(context, Icons.book_outlined, "My Courses", '/courses', currentRoute == '/courses'),
          _navItem(context, Icons.assignment_outlined, "Grading", '/grading', currentRoute == '/grading'),
          _navItem(context, Icons.analytics_outlined, "Analytics & Reports", '/analytics', currentRoute == '/analytics'),
          _navItem(context, Icons.person_outline, "Academic Profile", '/profile', currentRoute == '/profile'),
          _navItem(context, Icons.science_outlined, "Research", '/research', currentRoute == '/research'),
          _navItem(context, Icons.settings_outlined, "Settings", '/settings', currentRoute == '/settings'),
                    
          const Spacer(),
          const Divider(indent: 20, endIndent: 20),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () => _showLogoutConfirmation(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, String route, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF9333EA) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(icon, 
            color: isActive ? Colors.white : Colors.grey[600], 
            size: 22),
          title: Text(label,
            style: GoogleFonts.inter(
              color: isActive ? Colors.white : Colors.black87,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
            )),
          onTap: () {
            if (!isActive) {
              Navigator.pop(context);
              final args = ModalRoute.of(context)?.settings.arguments;
              Navigator.pushNamed(context, route, arguments: args);
            }
          },
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}