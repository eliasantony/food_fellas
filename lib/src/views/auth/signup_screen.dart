import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_signin_button/button_view.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:food_fellas/src/utils/auth_utils.dart';
import 'package:food_fellas/src/views/auth/login_screen.dart';
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

  bool _obscurePassword = true;

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

      // Attempt to Create User
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
        // Prompt user to log in instead
        bool shouldLogin = await _showLoginPrompt();
        if (shouldLogin) {
          // Attempt to sign in
          bool signInSuccess = await _attemptSignInWithEmail();
          if (!signInSuccess) {
            setState(() {
              _emailError =
                  'An account with this email already exists. Please check your password or reset it.';
            });
          }
        } else {
          setState(() {
            _emailError = 'An account with this email already exists.';
          });
        }
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

  Future<bool> _showLoginPrompt() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Account Exists'),
            content: const Text(
                'An account with this email already exists. Would you like to log in instead?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Log In'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _attemptSignInWithEmail() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      User? user = _auth.currentUser;
      if (user != null) {
        // Use the common post sign-in handler
        await handlePostSignIn(context, user);
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        setState(() {
          _passwordError = 'Incorrect password.';
        });
      } else if (e.code == 'user-not-found') {
        setState(() {
          _emailError = 'No user found for that email.';
        });
      } else {
        setState(() {
          _emailError = 'Sign in failed: ${e.message}';
        });
      }
      return false;
    } catch (e) {
      setState(() {
        _emailError = 'An unknown error occurred: $e';
      });
      return false;
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

      // Check if this is a new user (you can add additional onboarding logic here)
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        if (kDebugMode) {
          print('New Google user signed up');
        }
      } else {
        if (kDebugMode) {
          print('Existing Google user signed in');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error signing in with Google: $e');
      }
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

      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        if (kDebugMode) {
          print('New Apple user signed up');
        }
      } else {
        if (kDebugMode) {
          print('Existing Apple user signed in');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error signing in with Apple: $e');
      }
      setState(() {
        _emailError = 'Apple Sign-In failed: $e';
      });
    }
  }

  Future<void> _continueAsGuest() async {
    bool shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Continue as Guest"),
            content: const Text(
                "Continuing as a guest will limit many features of the app. Do you wish to proceed?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Continue"),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldContinue) return;

    try {
      // Option 1: Sign in anonymously using Firebase
      UserCredential userCredential =
          await FirebaseAuth.instance.signInAnonymously();
      // Option 2: If you prefer to simply navigate without authentication,
      // ensure your app handles a null or guest user appropriately.

      // Navigate directly to the home screen (or main page)
      Navigator.pushReplacementNamed(context, '/mainPage');
    } catch (e) {
      // Handle errors here if needed
      if (kDebugMode) {
        print('Error during anonymous sign in: $e');
      }
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
              TextFormField(
                controller: _emailController,
                autofillHints: [AutofillHints.newUsername, AutofillHints.email],
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
              TextFormField(
                controller: _passwordController,
                autofillHints: [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Create a password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _passwordError != null ? Colors.red : Colors.grey,
                    ),
                  ),
                  errorText: _passwordError,
                  // Suffix icon for toggling password visibility:
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
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
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginScreen(
                        email: _emailController.text,
                        password: _passwordController.text,
                      ),
                    ),
                  );
                },
                child: const Text('Already have an account? Log in'),
              ),
              TextButton(
                onPressed: _continueAsGuest,
                child: Text('Continue as Guest'),
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
