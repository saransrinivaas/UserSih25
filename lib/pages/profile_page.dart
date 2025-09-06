import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

enum AppLang { en, hi }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scroll = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loading = true;
  AppLang _lang = AppLang.en;
  int _bottomIndex = 0;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  static const Map<AppLang, Map<String, Map<String, String>>> _translations = {
    AppLang.en: {
      'profile': {
        'title': 'Profile',
        'contact': 'Contact',
        'address': 'Address',
        'update': 'Update Profile',
        'logout': 'Logout',
        'delete': 'Delete Account',
      },
      'home': {
        'title': 'City Connect',
        'profile': 'Profile',
        'report': 'Reports',
        'logout': 'Logout',
        'delete': 'Delete Account',
      }
    },
    AppLang.hi: {
      'profile': {
        'title': 'प्रोफ़ाइल',
        'contact': 'संपर्क',
        'address': 'पता',
        'update': 'प्रोफ़ाइल अपडेट करें',
        'logout': 'लॉगआउट',
        'delete': 'खाता हटाएं',
      },
      'home': {
        'title': 'सिटी कनेक्ट',
        'profile': 'प्रोफ़ाइल',
        'report': 'रिपोर्ट',
        'logout': 'लॉग आउट',
        'delete': 'खाता हटाएं',
      }
    },
  };

  Map<String, String> _t(String ns) => _translations[_lang]![ns]!;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final data = snapshot.data();
      setState(() {
        _nameController.text = data?['name'] ?? '';
        _emailController.text = user.email ?? '';
        _contactController.text = data?['contact'] ?? '';
        _addressController.text = data?['address'] ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'name': _nameController.text,
          'contact': _contactController.text,
          'address': _addressController.text,
        });
        Fluttertoast.showToast(msg: 'Profile updated successfully!', gravity: ToastGravity.BOTTOM);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e', gravity: ToastGravity.BOTTOM);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    bool confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Confirm Delete'),
            content: const Text('Are you sure you want to delete your account?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
      Fluttertoast.showToast(msg: 'Account deleted successfully!', gravity: ToastGravity.BOTTOM);
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e', gravity: ToastGravity.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tProfile = _t('profile');
    final tHome = _t('home');
    final themeGreen = const Color(0xFF2E582D);
    final lightBg = const Color(0xFFF1F8E9);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: lightBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: lightBg,
        centerTitle: true,
        title: Text(tProfile['title']!, style: const TextStyle(color: Color(0xFF1B1B1B), fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.menu, color: Color(0xFF1B1B1B)), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ToggleButtons(
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
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(tHome['profile'] ?? ''),
                onTap: () => Navigator.pushReplacementNamed(context, '/profile'),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: Text(tHome['title'] ?? ''),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/home');
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(tHome['report'] ?? ''),
                onTap: () => Navigator.pushReplacementNamed(context, '/report'),
              ),
              const Spacer(),
              Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(tHome['logout'] ?? ''),
                onTap: _logout,
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: Text(tHome['delete'] ?? ''),
                onTap: _deleteAccount,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CircleAvatar(radius: 50, backgroundColor: themeGreen, child: const Icon(Icons.person, size: 50, color: Colors.white)),
              const SizedBox(height: 20),
              _buildTextField(controller: _nameController, label: 'Name', icon: Icons.person),
              const SizedBox(height: 12),
              _buildTextField(controller: _emailController, label: 'Email', icon: Icons.email, readOnly: true),
              const SizedBox(height: 12),
              _buildTextField(controller: _contactController, label: tProfile['contact']!, icon: Icons.phone),
              const SizedBox(height: 12),
              _buildTextField(controller: _addressController, label: tProfile['address']!, icon: Icons.location_on),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tProfile['update']!, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomIndex,
        onDestinationSelected: (i) {
          setState(() => _bottomIndex = i);
          if (i == 0) return; // already profile
          if (i == 1) Navigator.pushReplacementNamed(context, '/home');
          if (i == 2) Navigator.pushReplacementNamed(context, '/report');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: ''),
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: ''),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: ''),
        ],
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool readOnly = false}) {
    final themeGreen = const Color(0xFF2E582D);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: themeGreen),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
