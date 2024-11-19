import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:food_fellas/src/models/aimodel_config.dart';

class ChatProvider with ChangeNotifier {
  List<ChatMessage> messages = [];
  late GenerativeModel? model;
  late ChatSession? chatInstance;
  Map<String, dynamic>? userData;

  ChatProvider() {
    model = getGenerativeModel();
    chatInstance = model?.startChat();
    _fetchUserData();
  }

  void addMessage(ChatMessage message) {
    messages.add(message);
    notifyListeners();
  }

  Future<String> sendMessageToAI(String userMessage) async {
    final response = await chatInstance?.sendMessage(Content.text(userMessage));
    return response?.text ?? '';
  }

  void _fetchUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists) {
        userData = userDoc.data();
        model = getGenerativeModel(userData: userData);
        chatInstance = model?.startChat();
      }
    }
  }

  void reinitializeModel(bool preferencesEnabled) {
    model = getGenerativeModel(
        userData: userData, preferencesEnabled: preferencesEnabled);
    chatInstance = model?.startChat();
  }
}
