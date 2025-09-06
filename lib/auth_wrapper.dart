import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/splash_page.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isFirstInstall = false;

  @override
  void initState() {
    super.initState();
    _checkFirstInstall();
  }

  Future<void> _checkFirstInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seenWelcome') ?? false;

      if (!seen) {
        setState(() {
          _isFirstInstall = true;
        });
        await prefs.setBool('seenWelcome', true);
      }
    } catch (e) {
      print("Error checking first install: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SplashPage();
    if (_isFirstInstall) return const WelcomePage();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashPage();
        } else if (snapshot.hasData) {
          return const HomePage();
        } else {
          return const AuthPage();
        }
      },
    );
  }
}
