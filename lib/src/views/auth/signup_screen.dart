import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_signin_button/button_view.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:food_fellas/src/views/auth/user_info_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _emailError;
  String? _passwordError;

  Future<void> _signUpWithEmail() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    try {
      // Validate Email
      if (_emailController.text.trim().isEmpty) {
        setState(() {
          _emailError = 'Email cannot be empty';
        });
        return;
      }
      if (!_emailController.text.trim().contains('@')) {
        setState(() {
          _emailError = 'Enter a valid email address';
        });
        return;
      }

      // Validate Password
      if (_passwordController.text.isEmpty) {
        setState(() {
          _passwordError = 'Password cannot be empty';
        });
        return;
      }
      if (_passwordController.text.length < 6) {
        setState(() {
          _passwordError =
              'Password is too short. It must be at least 6 characters long.';
        });
        return;
      }

      // Create User
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Send Verification Email
      await userCredential.user?.sendEmailVerification();

      // Inform the user to verify email
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Verify Your Email"),
          content: const Text(
              "A verification email has been sent to your email address. Please verify to continue."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const UserInfoScreen()),
                );
              },
              child: const Text("Continue"),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        setState(() {
          _emailError = 'An account with this email already exists.';
        });
      } else if (e.code == 'weak-password') {
        setState(() {
          _passwordError = 'Password is too weak.';
        });
      } else {
        setState(() {
          _emailError = 'An error occurred: ${e.message}';
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

      // Check if this is a new user (you can add additional onboarding logic here)
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        print('New Google user signed up');
      } else {
        print('Existing Google user signed in');
      }
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

      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        print('New Apple user signed up');
      } else {
        print('Existing Apple user signed in');
      }
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
                  'Welcome to FoodFellas!',
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
                'Join the community and create\nyour FoodFellas Account',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Your email address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _emailError != null ? Colors.red : Colors.grey,
                    ),
                  ),
                  errorText: _emailError,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Create a password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _passwordError != null ? Colors.red : Colors.grey,
                    ),
                  ),
                  errorText: _passwordError,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signUpWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create Account',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Add a link to the LoginScreen
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Already have an account? Log in'),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text('Or sign up with'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 40),
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
