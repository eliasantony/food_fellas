import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_fellas/src/models/user_data.dart';

class FinalWelcomeScreen extends StatelessWidget {
  final UserData userData;

  const FinalWelcomeScreen({Key? key, required this.userData}) : super(key: key);

  void _navigateToHome(BuildContext context) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Upload profile image if available
      if (userData.profileImage != null) {
        String uid = user.uid;
        Reference storageRef =
            FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
        UploadTask uploadTask = storageRef.putFile(userData.profileImage!);

        TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
        String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        userData.photoUrl = downloadUrl;
      }

      // Save all data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'created_time': FieldValue.serverTimestamp(),
        'display_name': userData.displayName,
        'email': user.email,
        'last_active_time': FieldValue.serverTimestamp(),
        'photo_url': userData.photoUrl,
        'shortDescription': userData.shortDescription,
        'dietaryPreferences': userData.dietaryPreferences,
        'favoriteCuisines': userData.favoriteCuisines,
        'cookingSkillLevel': userData.cookingSkillLevel,
        'notificationsEnabled': userData.notificationsEnabled,
        'onboardingComplete': true,
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
    final userName = userData.displayName ?? 'Foodie';

    return Scaffold(
      // Add your celebration animations here
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TODO: Add confetti animation here
            Text(
              'All set, $userName!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Let\'s start cooking up something amazing!',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _navigateToHome(context),
              child: Text('Explore Recipes'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}