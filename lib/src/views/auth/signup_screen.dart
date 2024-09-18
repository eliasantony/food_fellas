import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Controllers for TextFields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Method to sign up with Email and Password
  Future<void> _signUpWithEmail() async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      // Navigate to User Info Screen
      Navigator.pushNamed(context, '/userInfo');
    } catch (e) {
      // Handle errors
      print(e);
    }
  }

  // Method to sign in with Google
  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      // Navigate to User Info Screen
      Navigator.pushNamed(context, '/userInfo');
    } catch (e) {
      print(e);
    }
  }

  // Method to sign in with Apple
  Future<void> _signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      await _auth.signInWithCredential(oauthCredential);

      // Navigate to User Info Screen
      Navigator.pushNamed(context, '/userInfo');
    } catch (e) {
      print(e);
    }
  }

  void _skipSignUp() {
    Navigator.pushNamed(context, '/userInfo');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Add your playful elements here
      appBar: AppBar(
        title: const Text('Create an Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Social Sign-In Buttons
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                onPressed: _signInWithGoogle,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Apple'),
                onPressed: _signInWithApple,
              ),
              const SizedBox(height: 20),
              const Text('Or sign up with email'),
              const SizedBox(height: 10),
              // Name TextField
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'What\'s your name?',
                ),
              ),
              // Email TextField
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Your email address',
                ),
              ),
              // Password TextField
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Create a password',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUpWithEmail,
                child: const Text('Create Account'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _skipSignUp,
                child: const Text('Maybe Later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
