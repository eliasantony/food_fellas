import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserDataProvider with ChangeNotifier {
  bool _isSubscribed = false;
  Map<String, dynamic>? _userData;

  bool get isSubscribed => _isSubscribed;
  Map<String, dynamic>? get userData => _userData;

  void setUserData(Map<String, dynamic>? data) {
    _userData = data;
    notifyListeners();
  }

  void updateLastActiveTimeInFirestore(String uid) {
    if (_userData != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'last_active_time': FieldValue.serverTimestamp()});
    }
  }

  void fetchSubscriptionStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        _isSubscribed = doc.data()?['subscribed'] ?? false;
        notifyListeners(); // Updates UI immediately
      }
    });
  }

  void setSubscribed(bool value) {
    if (_userData != null) {
    _isSubscribed = value; // Update immediately
      _userData!['subscribed'] = value;
      notifyListeners();
    }
  }

  Future<void> updateUserData(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        _userData = userDoc.data();
      } else {
        // If the document doesn't exist (likely for an anonymous user),
        // set some default guest values.
        _userData = {
          'display_name': 'Guest',
          'photo_url':
              'https://firebasestorage.googleapis.com/v0/b/food-fellas-rts94q.appspot.com/o/DefaultAvatar.png?alt=media&token=c81b4254-54d5-4d2f-8b8c-5c8db6dab690',
        };
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating user data: $e');
      }
    }
  }
}
