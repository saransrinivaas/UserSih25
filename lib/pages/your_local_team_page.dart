import 'package:flutter/material.dart';
import 'widgets/app_botton_nav.dart';
import 'widgets/app_drawer.dart';

class YourLocalTeamPage extends StatelessWidget {
  const YourLocalTeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lightBg = const Color(0xFFF1F8E9);
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: lightBg,
        centerTitle: true,
        title: const Text('Your Local Team', style: TextStyle(color: Color(0xFF1B1B1B), fontWeight: FontWeight.w700)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1B1B1B)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: const SizedBox.shrink(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
} 