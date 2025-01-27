import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:food_fellas/src/models/aimodel_config.dart';

class ChatProvider with ChangeNotifier {
  List<ChatMessage> messages = [];
  late GenerativeModel? model;
  late ChatSession? chatInstance;
  Map<String, dynamic>? userData;
  String? conversationId;

  ChatProvider() {
    _fetchUserData();
  }

  Future<void> _loadLastConversation() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Fetch the last conversation based on 'createdAt'
    final conversationsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('conversations')
        .orderBy('createdAt', descending: true)
        .limit(1);

    final conversationsSnapshot = await conversationsRef.get();

    if (conversationsSnapshot.docs.isNotEmpty) {
      final lastConversation = conversationsSnapshot.docs.first;
      conversationId = lastConversation.id;

      // Fetch all messages from the last conversation
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt')
          .get();

      messages = messagesSnapshot.docs.map((doc) {
        return _mapFirestoreToChatMessage(doc.id, doc.data());
      }).toList();

      notifyListeners();
    }
    // If no previous conversation exists, do nothing
  }

  // Clears the local chat messages and resets the chat session.
  void clearChat() {
    messages.clear();
    conversationId = null; // Optionally reset the conversation ID
    _reinitializeChatInstance(); // Start a fresh chat session
    notifyListeners();
  }

  /// Reinitializes the chat instance to start a new conversation.
  void _reinitializeChatInstance() {
    if (model != null) {
      chatInstance = model!.startChat();
    }
  }

  String _generateConversationId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void addMessages(List<ChatMessage> newMessages,
      {bool saveToFirestore = true}) {
    bool hasChanges = false;
    for (var message in newMessages) {
      String? messageId = message.customProperties?['id'];
      if (messageId == null) {
        // If 'id' is not present, assign a temporary unique ID
        message.customProperties = {
          ...message.customProperties ?? {},
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
        };
      }

      bool exists = messages.any((msg) =>
          msg.customProperties?['id'] == message.customProperties?['id']);
      if (!exists) {
        messages.add(message);
        hasChanges = true;

        if (saveToFirestore) {
          if (conversationId == null) {
            _createNewConversation();
          }
          _saveMessageToFirestore(message);
        }
      }
    }
    if (hasChanges) {
      notifyListeners();
    }
  }

  Future<void> _createNewConversation() async {
    conversationId = _generateConversationId();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final conversationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('conversations')
          .doc(conversationId);

      await conversationRef.set({
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // **New Method to Fetch the Last Three AI Messages**
  Future<List<ChatMessage>> getLastAIMessages() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    try {
      // Fetch the last conversation
      final conversationsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('conversations')
          .orderBy('createdAt', descending: true)
          .limit(1);

      final conversationsSnapshot = await conversationsRef.get();

      if (conversationsSnapshot.docs.isEmpty) return [];

      final lastConversation = conversationsSnapshot.docs.first;
      final lastConversationId = lastConversation.id;

      // Fetch the last three AI messages in that conversation
      final messagesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('conversations')
          .doc(lastConversationId)
          .collection('messages')
          .where('customProperties.isAIMessage', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(3);

      final messagesSnapshot = await messagesRef.get();

      if (messagesSnapshot.docs.isEmpty) return [];

      // Map Firestore documents to ChatMessage objects
      List<ChatMessage> aiMessages = messagesSnapshot.docs.map((doc) {
        return _mapFirestoreToChatMessage(doc.id, doc.data());
      }).toList();

      // Reverse to maintain chronological order
      return aiMessages.reversed.toList();
    } catch (e) {
      print('Error fetching last AI messages: $e');
      return [];
    }
  }

  ChatMessage _mapFirestoreToChatMessage(
      String docId, Map<String, dynamic> data) {
    return ChatMessage(
      user: ChatUser.fromJson(data['user'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      text: data['text'] ?? '',
      medias: data['medias'] != null
          ? (data['medias'] as List)
              .map((media) => ChatMedia.fromJson(media))
              .toList()
          : null,
      quickReplies: data['quickReplies'] != null
          ? (data['quickReplies'] as List)
              .map((qr) => QuickReply.fromJson(qr))
              .toList()
          : null,
      customProperties: {
        ...data['customProperties'] ?? {},
        'id': docId, // Assign Firestore document ID
      },
    );
  }

  Future<String> sendMessageToAI(String userMessage) async {
    final response = await chatInstance?.sendMessage(Content.text(userMessage));
    return response?.text ?? '';
  }

  Future<void> _fetchUserData() async {
    try {
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
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
      // Optionally, handle the error (e.g., notify the user)
    }
  }

  void reinitializeModel(bool preferencesEnabled) {
    model = getGenerativeModel(
        userData: userData, preferencesEnabled: preferencesEnabled);
    chatInstance = model?.startChat();
  }

  Future<void> _saveMessageToFirestore(ChatMessage message) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && conversationId != null) {
      final messageRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(); // Auto-generated ID

      await messageRef.set(_messageToMap(message, messageRef.id));

      // Update the message in the local list with the Firestore document ID
      message.customProperties = {
        ...message.customProperties ?? {},
        'id': messageRef.id,
      };
      notifyListeners();
    }
  }

  Map<String, dynamic> _messageToMap(ChatMessage message, String messageId) {
    return {
      'id': messageId,
      'user': message.user.toJson(),
      'text': message.text,
      'createdAt': message.createdAt,
      'customProperties': message.customProperties,
      'medias': message.medias?.map((media) => media.toJson()).toList(),
    };
  }
}
