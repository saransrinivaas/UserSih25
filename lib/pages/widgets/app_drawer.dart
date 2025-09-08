import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth auth = FirebaseAuth.instance;

    Future<void> _logout() async {
      await auth.signOut();
      if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
    }

    Future<void> _deleteAccount() async {
      final user = auth.currentUser;
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
        await user.delete();
      } catch (_) {}
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            ListTile(leading: const Icon(Icons.person), title: const Text('Profile'), onTap: () => Navigator.pushReplacementNamed(context, '/profile')),
            ListTile(leading: const Icon(Icons.home), title: const Text('Home'), onTap: () => Navigator.pushReplacementNamed(context, '/home')),
            ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Reports'), onTap: () => Navigator.pushReplacementNamed(context, '/report')),
            ListTile(leading: const Icon(Icons.notifications), title: const Text('Notifications'), onTap: () => Navigator.pushReplacementNamed(context, '/notifications')),
            ListTile(leading: const Icon(Icons.groups), title: const Text('Your Local Team'), onTap: () => Navigator.pushReplacementNamed(context, '/local_team')),
            const Spacer(),
            const Divider(),
            ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: _logout),
            ListTile(leading: const Icon(Icons.delete_forever), title: const Text('Delete Account'), onTap: _deleteAccount),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
} 