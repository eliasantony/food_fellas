import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Streams for real-time updates
  Stream<QuerySnapshot> getRecipeFeedback() {
    return _firestore
        .collection('recipe_feedback')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getOverallFeedback() {
    return _firestore
        .collection('feedback')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
