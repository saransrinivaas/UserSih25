import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> _pages = [
    {
      "svg": "assets/svgs/Welcome-amico.svg",
      "title": "Report Issues",
      "subtitle":
          "Quickly capture civic issues like potholes, streetlights, and garbage bins."
    },
    {
      "svg": "assets/svgs/track.svg",
      "title": "Track Progress",
      "subtitle":
          "Stay informed with real-time updates as departments work on your reports."
    },
    {
      "svg": "assets/svgs/notify.svg",
      "title": "Stay Connected",
      "subtitle":
          "Get notified when issues are resolved and verified by the community."
    },
  ];

  void _nextPage() {
    if (_currentIndex == _pages.length - 1) {
      _finishOnboarding();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() {
    Navigator.pushReplacementNamed(context, "/login");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9), // match splash bg
      body: SafeArea(
        child: Column(
          children: [
            // Animated carousel
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.1, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      key: ValueKey(index),
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // SVG Illustration with smooth fade/slide
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SvgPicture.asset(
                              page["svg"]!,
                              height: MediaQuery.of(context).size.height * 0.28,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            page["title"]!,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B1B1B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            page["subtitle"]!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF4E5D4A),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Indicators + Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  // Dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: _currentIndex == index ? 20 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? const Color(0xFF2E582D) // dark green
                              : const Color(0xFFA5D6A7), // mint green
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Next / Get Started button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E582D), // primary green
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      _currentIndex == _pages.length - 1
                          ? "Get Started"
                          : "Next",
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
