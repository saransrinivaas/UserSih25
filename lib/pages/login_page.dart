import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

 Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _loading = true);

  try {
    UserCredential userCredential;

    if (_isLogin) {
      // 🔑 Login flow
      userCredential = await _auth.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      debugPrint("✅ Logged in as: ${userCredential.user!.uid}");
    } else {
      // 🆕 Signup flow
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      debugPrint("✅ New account created: ${userCredential.user!.uid}");

      // 🟢 Store user role in Firestore with error catching
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'email': _email.text.trim(),
          'role': 'end_user',
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint("✅ Firestore document created for ${userCredential.user!.uid}");
      } catch (firestoreError, st) {
        debugPrint("❌ Firestore write FAILED: $firestoreError");
        debugPrint("STACKTRACE: $st");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save user to Firestore")),
        );
      }
    }

    // 🔎 Fetch user data after login/signup
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!snapshot.exists) {
        debugPrint("⚠️ No Firestore document found for this user!");
      }

      final data = snapshot.data();
      debugPrint("📄 Firestore data: $data");

      if (data != null && data['role'] == 'end_user') {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        debugPrint("🚫 Role mismatch or missing.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: Not an end user')),
        );
        await _auth.signOut();
      }
    } catch (readError, st) {
      debugPrint("❌ Failed to read Firestore data: $readError");
      debugPrint("STACKTRACE: $st");
    }
  } on FirebaseAuthException catch (e) {
    debugPrint("❌ Firebase Auth Error: ${e.code} - ${e.message}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message ?? 'Authentication error')),
    );
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    final themeGreen = const Color(0xFF2E582D);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_circle, size: 80, color: themeGreen),
                  const SizedBox(height: 10),
                  Text(
                    _isLogin ? "Welcome Back!" : "Create Account",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // 📧 Email Field
                  TextFormField(
                    controller: _email,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: const Color(0xFFF9FBF7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        v != null && v.contains('@') ? null : "Enter a valid email",
                  ),
                  const SizedBox(height: 12),

                  // 🔑 Password Field
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      fillColor: const Color(0xFFF9FBF7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        v != null && v.length >= 6 ? null : "Min 6 characters required",
                  ),
                  const SizedBox(height: 20),

                  // 🚀 Login/Signup Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_isLogin ? 'Login' : 'Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🔄 Switch Between Login & Signup
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign up"
                          : "Already have an account? Login",
                      style: TextStyle(color: themeGreen),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
