import 'package:lottie/lottie.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_fellas/src/models/user_data.dart';

class FinalWelcomeScreen extends StatelessWidget {
  final UserData userData;

  const FinalWelcomeScreen({Key? key, required this.userData})
      : super(key: key);

  void _navigateToHome(BuildContext context) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Upload profile image if available
      if (userData.profileImage != null) {
        String uid = user.uid;
        Reference storageRef =
            FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
        UploadTask uploadTask = storageRef.putData(userData.profileImage!);

        TaskSnapshot taskSnapshot;
        try {
          taskSnapshot = await uploadTask;
        } catch (e) {
          print('Upload failed: $e');
          return;
        }
        String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        userData.photoUrl = downloadUrl;
      }

      // Save all data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'created_time': FieldValue.serverTimestamp(),
        'display_name': userData.displayName,
        'email': user.email,
        'last_active_time': FieldValue.serverTimestamp(),
        'photo_url': userData.photoUrl,
        'shortDescription': userData.shortDescription,
        'dietaryPreferences': userData.dietaryPreferences,
        'favoriteCuisines': userData.favoriteCuisines,
        'cookingSkillLevel': userData.cookingSkillLevel,
        'preferredServings': userData.preferredServings,
        'notificationsEnabled': userData.notificationsEnabled,
        'onboardingComplete': true,
        'role': 'user',
      }, SetOptions(merge: true));
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/mainPage',
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Lottie animation in the background
          Positioned.fill(
            child: ClipRect(
              child: Lottie.asset(
                'lib/assets/lottie/confetti.json',
                repeat: false,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Your existing layout goes here
          Positioned.fill(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center the children vertically
              children: [
                Text(
                  'All set, ${userData.displayName}!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Let\'s start cooking up \n something amazing!',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                SizedBox(height: 40),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _navigateToHome(context),
                      child: Text('Explore Recipes'),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
