// utils/auth_utils.dart (create a new file)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/src/views/auth/user_info_screen.dart';

Future<void> handlePostSignIn(BuildContext context, User? user) async {
  if (user == null) return;

  // Fetch user document from Firestore
  DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

  if (userDoc.exists && userDoc['onboardingComplete'] == true) {
    // Navigate to Home Screen
    Navigator.pushNamedAndRemoveUntil(context, '/mainPage', (route) => false);
  } else {
    // Navigate to UserInfoScreen for onboarding
    if (kDebugMode) {
      print('Navigating to UserInfoScreen');
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserInfoScreen()),
    );
  }
}
