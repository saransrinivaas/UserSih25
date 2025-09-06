import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_wrapper.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/profile_page.dart';
import 'pages/report_page.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/home': (context) => const HomePage(),
        '/login': (context) => const AuthPage(),
        '/profile': (context) => const ProfilePage(),
        '/report': (context) => const ReportsPage(),
      },
    );
  }
}
