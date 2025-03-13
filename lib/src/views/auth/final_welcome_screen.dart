import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:lottie/lottie.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_fellas/src/models/user_data.dart';
import 'package:provider/provider.dart';

class FinalWelcomeScreen extends StatefulWidget {
  final UserData userData;

  const FinalWelcomeScreen({super.key, required this.userData});

  @override
  _FinalWelcomeScreenState createState() => _FinalWelcomeScreenState();
}

class _FinalWelcomeScreenState extends State<FinalWelcomeScreen> {
  bool _documentCreated = false;

  @override
  void initState() {
    super.initState();
    _createUserDocument();
  }

  Future<void> _createUserDocument() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Upload profile image if available
      if (widget.userData.profileImage != null) {
        String uid = user.uid;
        Reference storageRef =
            FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
        UploadTask uploadTask =
            storageRef.putData(widget.userData.profileImage!);

        TaskSnapshot taskSnapshot;
        try {
          taskSnapshot = await uploadTask;
        } catch (e) {
          return;
        }
        String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        widget.userData.photoUrl = downloadUrl;
      }
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        fcmToken = null;
      }

      // Save all data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'created_time': FieldValue.serverTimestamp(),
        'display_name': widget.userData.displayName,
        'email': user.email,
        'last_active_time': FieldValue.serverTimestamp(),
        'photo_url': widget.userData.photoUrl ??
            'https://firebasestorage.googleapis.com/v0/b/food-fellas-rts94q.appspot.com/o/DefaultAvatar.png?alt=media&token=c81b4254-54d5-4d2f-8b8c-5c8db6dab690',
        'shortDescription': widget.userData.shortDescription,
        'dietaryPreferences': widget.userData.dietaryPreferences,
        'favoriteCuisines': widget.userData.favoriteCuisines,
        'cookingSkillLevel': widget.userData.cookingSkillLevel,
        'preferredServings': widget.userData.preferredServings,
        'notificationsEnabled': widget.userData.allNotificationsEnabled,
        'notifications': widget.userData.notifications, // Save preferences here
        'averageRating': 0.0,
        'recipeCount': 0,
        'onboardingComplete': true,
        'role': 'user',
        if (fcmToken != null) 'fcmToken': fcmToken,
      }, SetOptions(merge: true));

      // Mark document creation complete
      setState(() {
        _documentCreated = true;
      });
// After saving user document...
      await Provider.of<UserDataProvider>(context, listen: false)
          .updateUserData(user.uid);
    } else {
      print('[FinalWelcomeScreen] _createUserDocument: No user logged in');
    }
  }

  void _navigateToHome(BuildContext context) {
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
          // Main content layout
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'All set, ${widget.userData.displayName}!',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Let\'s start cooking up \n something amazing!',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _navigateToHome(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: Text(
                        'Explore Recipes',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_documentCreated)
            const Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
