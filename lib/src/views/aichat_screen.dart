import 'dart:io';
import 'dart:typed_data';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:food_fellas/src/models/aimodel_config.dart';
import 'package:image_picker/image_picker.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  List<ChatMessage> messages = [];

  ChatUser currentUser = ChatUser(id: "0", firstName: "User");
  ChatUser geminiUser = ChatUser(
    id: "1",
    firstName: "FoodFella Assist",
    profileImage:
        "https://seeklogo.com/images/G/google-gemini-logo-A5787B2669-seeklogo.com.png",
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("FoodFellas AI Assistant"),
      ),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return DashChat(
      inputOptions: InputOptions(trailing: [
        IconButton(
          onPressed: _sendMediaMessage,
          icon: const Icon(Icons.image),
        )
      ]),
      quickReplyOptions: QuickReplyOptions(
        onTapQuickReply: _onQuickReply,
      ),
      messageOptions: MessageOptions(
        messageDecorationBuilder: (ChatMessage message,
            ChatMessage? previousMessage, ChatMessage? nextMessage) {
          if (message.customProperties?['isAIMessage'] == true) {
            return BoxDecoration(
              color: Colors.lightBlueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.0),
            );
          }
          return BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.0),
          );
        },
        messageTextBuilder: (ChatMessage message, ChatMessage? previousMessage,
            ChatMessage? nextMessage) {
          return MarkdownBody(
            data: message.text ?? '',
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                color: Colors.black,
              ),
              strong: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              blockquote: TextStyle(
                color: Colors.black,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        },
      ),
      currentUser: currentUser,
      onSend: _sendMessage,
      messages: messages,
    );
  }

  List<QuickReply> _getQuickReplies() {
    return [
      QuickReply(
        title: "Quick and Easy Recipes 🕒",
        value: "Quick and Easy Recipes 🕒",
      ),
      QuickReply(
        title: "Surprise Me! 🎲",
        value: "Surprise Me! 🎲",
      ),
      QuickReply(
        title: "Use My Ingredients 🥕🍅",
        value: "Use My Ingredients 🥕🍅",
      ),
    ];
  }

  void _onQuickReply(QuickReply reply) {
    ChatMessage quickReplyMessage = ChatMessage(
      user: currentUser,
      createdAt: DateTime.now(),
      text: reply.value ?? '',
    );
    _sendMessage(quickReplyMessage);
  }

  Future<void> _sendMessage(ChatMessage chatMessage) async {
    setState(() {
      messages = [chatMessage, ...messages];
    });

    try {
      final prompt = [Content.text(chatMessage.text)];
      List<Uint8List>? images;
      if (chatMessage.medias?.isNotEmpty ?? false) {
        images = [
          File(chatMessage.medias!.first.url).readAsBytesSync(),
        ];
      }

      final model = getGenerativeModel();
      final chat = model?.startChat();

      final response = await chat?.sendMessage(prompt.first);
      String formatMessage(String message) {
        final boldPattern = RegExp(r'\*\*(.*?)\*\*');
        return message.replaceAllMapped(boldPattern, (match) {
          return '**${match.group(1)}**';
        });
      }

      final formatedResponse = formatMessage(response?.text ?? '');
      print(formatedResponse);

      ChatMessage aiMessage = ChatMessage(
        user: geminiUser,
        createdAt: DateTime.now(),
        text: formatedResponse,
        customProperties: {"isAIMessage": true},
        quickReplies: _getQuickReplies(),
      );

      setState(() {
        messages = [aiMessage, ...messages];
      });
    } catch (e) {
      // Log or handle the error properly in UI
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _sendMediaMessage() async {
    ImagePicker picker = ImagePicker();
    XFile? file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      ChatMessage chatMessage = ChatMessage(
        user: currentUser,
        createdAt: DateTime.now(),
        text: "Try to accurately guess this recipe based on the picture!",
        medias: [
          ChatMedia(
            url: file.path,
            fileName: "",
            type: MediaType.image,
          )
        ],
      );

      _sendMessage(chatMessage);
    }
  }
}
