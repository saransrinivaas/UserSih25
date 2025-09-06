import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AppLang { en, hi }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  AppLang _lang = AppLang.en;
  int _bottomIndex = 2; // Reports tab
  final themeGreen = const Color(0xFF2E582D);
  final lightBg = const Color(0xFFF1F8E9);
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _onBottomNavSelected(int i) {
    setState(() => _bottomIndex = i);
    if (i == 0) Navigator.pushReplacementNamed(context, '/profile');
    if (i == 1) Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final title = _lang == AppLang.en ? 'Reports' : 'रिपोर्ट्स';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: lightBg,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: Color(0xFF1B1B1B))),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1B1B1B)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          ToggleButtons(
            isSelected: [_lang == AppLang.en, _lang == AppLang.hi],
            onPressed: (i) => setState(() => _lang = i == 0 ? AppLang.en : AppLang.hi),
            borderRadius: BorderRadius.circular(12),
            selectedColor: Colors.white,
            fillColor: themeGreen,
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('EN')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('हिं')),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: themeGreen),
              child: const Text('User', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/report');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Delete Account'),
              onTap: () {}, // implement later
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Reports page is empty', style: TextStyle(fontSize: 20)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomIndex,
        onDestinationSelected: _onBottomNavSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: ''),
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: ''),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: ''),
        ],
      ),
    );
  }
}
