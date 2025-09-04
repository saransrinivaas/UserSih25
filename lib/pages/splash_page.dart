import 'dart:async';
import 'package:flutter/material.dart';
import 'welcome_page.dart'; // make sure you import this

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _animate = false;

  @override
  void initState() {
    super.initState();

    // Blooming (scale in/out) animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation =
        Tween<double>(begin: 0.9, end: 1.1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Fade-in trigger
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() => _animate = true);
    });

    // Navigate with smooth left-slide
    Timer(const Duration(seconds: 6), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1800),
          pageBuilder: (_, __, ___) => const WelcomePage(),
          transitionsBuilder: (_, animation, __, child) {
            const begin = Offset(1.0, 0.0); // from right
            const end = Offset.zero;
            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOut));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9), // light mild green creme
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: AnimatedOpacity(
                opacity: _animate ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1500),
                child: Image.asset(
                  "assets/images/logo.png", // replace with your logo
                  height: MediaQuery.of(context).size.height * 0.22, // bigger logo
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedOpacity(
              opacity: _animate ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 2000),
              child: Column(
                children: const [
                  Text(
                    "Civic Connect", // App name
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E582D), // primary green
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Your city, your voice",
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4E5D4A), // muted green text
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
