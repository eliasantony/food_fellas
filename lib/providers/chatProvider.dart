import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';

class ChatProvider with ChangeNotifier {
  List<ChatMessage> _messages = [];

  List<ChatMessage> get messages => _messages;

  void addMessage(ChatMessage message) {
    _messages = [message, ..._messages];
    notifyListeners();
  }

  void addMessages(List<ChatMessage> messages) {
    _messages = [...messages, ..._messages];
    notifyListeners();
  }
}
