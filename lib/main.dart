import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';

import 'auth_wrapper.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/profile_page.dart';
import 'pages/report_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();

    // ✅ Request location permission on startup
    await _requestLocationPermission();

    runApp(const MyApp());
  } catch (e, stack) {
    debugPrint("❌ Firebase initialization failed: $e");
    debugPrintStack(stackTrace: stack);
    runApp(const FirebaseErrorApp());
  }
}

/// Ask for location permission at startup
Future<void> _requestLocationPermission() async {
  final status = await Permission.location.status;

  if (status.isDenied || status.isRestricted) {
    final result = await Permission.location.request();
    if (result.isDenied) {
      debugPrint("⚠️ Location permission denied. Some features may not work.");
    }
  }

  if (await Permission.location.isPermanentlyDenied) {
    debugPrint("⚠️ Location permission permanently denied. Ask user to enable it in settings.");
    // Optionally: openAppSettings();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2E582D),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E582D)),
        fontFamily: 'Roboto',
      ),
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

class FirebaseErrorApp extends StatelessWidget {
  const FirebaseErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            "Failed to initialize Firebase.\nPlease restart the app.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      ),
    );
  }
}
