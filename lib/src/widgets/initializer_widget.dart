import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/views/auth/user_info_screen.dart';
import 'package:food_fellas/src/views/auth/welcome_screen.dart';
import 'package:food_fellas/main.dart';
import 'package:provider/provider.dart';

class InitializerWidget extends StatefulWidget {

  const InitializerWidget({
    super.key,
  });

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

  Future<void> _fetchUserData(String uid) async {
    Provider.of<UserDataProvider>(context, listen: false).updateUserData(uid);
  }

@override
  Widget build(BuildContext context) {
    if (_error) {
      return _buildErrorScreen();
    }

    if (!_initialized) {
      return _buildLoadingScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorScreen();
        }

        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return const WelcomeScreen();
          } else {
            return _checkOnboarding(user);
          }
        }

        return _buildLoadingScreen();
      },
    );
  }

  Widget _buildErrorScreen() {
    return const Scaffold(
      body: Center(
        child: Text('Error initializing Firebase. Please try again later.'),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _checkOnboarding(User user) {
    return FutureBuilder<bool>(
      future: checkOnboardingComplete(user.uid),
      builder: (context, onboardingSnapshot) {
        if (onboardingSnapshot.hasError) {
          return _buildErrorScreen();
        }

        if (onboardingSnapshot.connectionState == ConnectionState.done) {
          final onboardingComplete = onboardingSnapshot.data ?? false;
          if (onboardingComplete) {
            _fetchUserData(
                user.uid); // Fetch user data when onboarding is complete
            return MainPage();
          } else {
            return const WelcomeScreen();
          }
        }

        return _buildLoadingScreen();
      },
    );
  }
}
