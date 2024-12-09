import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _emailError;
  String? _passwordError;

  Future<void> _signInWithEmail() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    try {
      if (_emailController.text.trim().isEmpty) {
        setState(() {
          _emailError = 'Email cannot be empty';
        });
        return;
      }

      if (_passwordController.text.isEmpty) {
        setState(() {
          _passwordError = 'Password cannot be empty';
        });
        return;
      }

      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Navigate to InitializerWidget to decide where to go next
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        setState(() {
          _emailError = 'No user found for that email.';
        });
      } else if (e.code == 'wrong-password') {
        setState(() {
          _passwordError = 'Wrong password provided.';
        });
      } else {
        print('Error: $e');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Build your login UI here
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              Text(
                'Log In',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 30),
              if (_emailError != null)
                Text(
                  _emailError!,
                  style: const TextStyle(color: Colors.red),
                ),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Your email address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_passwordError != null)
                Text(
                  _passwordError!,
                  style: const TextStyle(color: Colors.red),
                ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Your password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signInWithEmail,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 140, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Log In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
