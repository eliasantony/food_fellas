// tag_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/src/models/tag.dart';

class TagProvider with ChangeNotifier {
  List<Tag> _tags = [];
  bool isLoaded = false;

  List<Tag> get tags => _tags;

  Future<void> fetchTags() async {
    if (isLoaded) return; // Avoid re-fetching

    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('tags').get();

    _tags = snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return Tag.fromMap(data, doc.id);
    }).toList();

    isLoaded = true;
    notifyListeners();
  }
}
