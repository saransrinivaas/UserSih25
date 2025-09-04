import 'package:flutter/material.dart';
import './pages/splash_page.dart';
import './pages/welcome_page.dart';

void main() {
  runApp(const CivicApp());
}

class CivicApp extends StatelessWidget {
  const CivicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: "/",
      routes: {
        "/": (context) => const SplashPage(),
        "/welcome": (context) => const WelcomePage(),
        "/home": (context) => const Scaffold(body: Center(child: Text("Home"))),
      },
    );
  }
}
