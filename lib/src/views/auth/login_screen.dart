import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_signin_button/button_list.dart';
import 'package:flutter_signin_button/button_view.dart';
import 'package:food_fellas/src/utils/auth_utils.dart';
import 'package:food_fellas/src/views/auth/forgot_password_screen.dart';
import 'package:food_fellas/src/views/auth/signup_screen.dart';
import 'package:food_fellas/src/views/auth/user_info_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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

      User? user = _auth.currentUser;
      if (user != null) {
        // Assuming you have a Firestore collection named 'users' where you store user data
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc['onboardingComplete'] == true) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        } else {
          // Navigate to the onboarding screen if onboarding is not complete
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserInfoScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          setState(() {
            _emailError = 'No user found for that email.';
          });
          break;
        case 'wrong-password':
          setState(() {
            _passwordError = 'Wrong password provided.';
          });
          break;
        case 'invalid-credential':
          setState(() {
            _emailError = 'The credential is invalid or expired.';
          });
          break;
        default:
          setState(() {
            _emailError = 'Authentication error: ${e.message}';
          });
      }
    } catch (e) {
      setState(() {
        _emailError = 'An unknown error occurred: $e';
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // User canceled the Google Sign-In

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      await handlePostSignIn(context, userCredential.user);
    } catch (e) {
      print('Error signing in with Google: $e');
      setState(() {
        _emailError = 'Google Sign-In failed: $e';
      });
    }
  }

  Future<void> _signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      await handlePostSignIn(context, userCredential.user);
    } catch (e) {
      print('Error signing in with Apple: $e');
      setState(() {
        _emailError = 'Apple Sign-In failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  'Welcome back to FoodFellas!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors
                            .white, // This color will be masked by the gradient
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Log in to access your recipes and more.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _emailController,
                autofillHints: [AutofillHints.username, AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Your email address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _emailError != null
                          ? Colors.red
                          : Colors.grey, // Change border color dynamically
                    ),
                  ),
                  errorText: _emailError, // Display error below the field
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                autofillHints: [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Your password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _passwordError != null
                          ? Colors.red
                          : Colors.grey, // Change border color dynamically
                    ),
                  ),
                  errorText: _passwordError, // Display error below the field
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signInWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 140, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Log In',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen()),
                  );
                },
                child: Text(
                  'Forgot your password?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    '/signup',
                  );
                },
                child: Text(
                  'Don\'t have an account? Sign Up',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Or',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              SignInButton(
                Buttons.Google,
                onPressed: _signInWithGoogle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 10),
              SignInButton(
                Buttons.Apple,
                onPressed: _signInWithApple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
