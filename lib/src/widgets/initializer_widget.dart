import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/src/views/auth/user_info_screen.dart';
import 'package:food_fellas/src/views/auth/welcome_screen.dart';
import 'package:food_fellas/main.dart';

class InitializerWidget extends StatefulWidget {
  const InitializerWidget({Key? key}) : super(key: key);

  @override
  _InitializerWidgetState createState() => _InitializerWidgetState();
}

class _InitializerWidgetState extends State<InitializerWidget> {
  bool _initialized = false;
  bool _error = false;

  // Function to initialize Firebase
  void initializeFlutterFire() async {
    try {
      // Wait for Firebase to initialize and set `_initialized` state to true
      print('Initializing Firebase...');
      await Firebase.initializeApp();
      print('Firebase initialized');
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      // Set `_error` state to true if Firebase initialization fails
      print('Firebase initialization error: $e');
      setState(() {
        _error = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initializeFlutterFire();
  }

  Future<bool> checkOnboardingComplete(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        return data?['onboardingComplete'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking onboarding status: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building InitializerWidget...');
    // Show error message if initialization failed
    if (_error) {
      return const Scaffold(
        body: Center(child: Text('Error initializing Firebase')),
      );
    }

    // Show loading indicator while Firebase is initializing
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Check for errors
        if (snapshot.hasError) {
          print('Auth state error: ${snapshot.error}');
          return const Scaffold(
            body: Center(child: Text('Something went wrong')),
          );
        }

        // Check the authentication state
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;

          if (user == null) {
            // User is not signed in
            print('User is not signed in');
            return const WelcomeScreen();
          } else {
            // User is signed in, check onboarding status
            return FutureBuilder<bool>(
              future: checkOnboardingComplete(user.uid),
              builder: (context, onboardingSnapshot) {
                if (onboardingSnapshot.hasError) {
                  print('Onboarding status error: ${onboardingSnapshot.error}');
                  return const Scaffold(
                    body: Center(child: Text('Something went wrong')),
                  );
                }

                if (onboardingSnapshot.connectionState == ConnectionState.done) {
                  bool onboardingComplete = onboardingSnapshot.data ?? false;

                  if (onboardingComplete) {
                    // Onboarding is complete
                    print('Onboarding complete, navigating to MainPage');
                    return const MainPage();
                  } else {
                    // Onboarding not complete
                    print('Onboarding not complete, navigating to UserInfoScreen');
                    return const UserInfoScreen();
                  }
                } else {
                  // Show loading indicator while checking onboarding status
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            );
          }
        } else {
          // Show loading indicator while checking authentication state
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}
