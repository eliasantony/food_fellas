import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:food_fellas/providers/chatProvider.dart';
import 'package:food_fellas/src/models/aimodel_config.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// Define your users
ChatUser currentUser = ChatUser(id: "0", firstName: "User");
ChatUser geminiUser = ChatUser(
  id: "1",
  firstName: "FoodFella Assist",
  profileImage:
      "https://seeklogo.com/images/G/google-gemini-logo-A5787B2669-seeklogo.com.png",
);

// Helper function to determine if a message contains a JSON recipe
Map<String, dynamic>? extractJsonRecipe(String text) {
  try {
    final Map<String, dynamic> decoded = json.decode(text);
    print(decoded);
    if (decoded.containsKey('title') &&
        decoded.containsKey('description') &&
        decoded.containsKey('cookingTime') &&
        decoded.containsKey('ingredients') &&
        decoded.containsKey('cookingSteps')) {
      return decoded;
    }
  } catch (e) {
    // Ignore parsing errors, just return null
  }
  return null;
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("FoodFellas AI Assistant"),
      ),
      body: DashChat(
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
            return BoxDecoration(
              color: message.customProperties?['isAIMessage'] == true
                  ? Colors.lightBlueAccent.withOpacity(0.1)
                  : Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.0),
            );
          },
          messageTextBuilder: (ChatMessage message,
              ChatMessage? previousMessage, ChatMessage? nextMessage) {
            // Check if the message contains a JSON recipe
            if (message.customProperties?['jsonRecipe'] != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
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
                  ),
                  SizedBox(height: 8.0),
                  ElevatedButton(
                    onPressed: () {
                      final recipeJson =
                          message.customProperties?['jsonRecipe'];
                      _navigateToAddRecipeForm(context, recipeJson);
                    },
                    child: Text('Add to Recipes'),
                  ),
                ],
              );
            } else {
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
            }
          },
        ),
        currentUser: currentUser,
        onSend: _sendMessage,
        messages: chatProvider.messages,
      ),
    );
  }

  // Handle quick replies
  void _onQuickReply(QuickReply reply) {
    ChatMessage quickReplyMessage = ChatMessage(
      user: currentUser,
      createdAt: DateTime.now(),
      text: reply.value ?? '',
    );
    _sendMessage(quickReplyMessage);
  }

  // Send message and handle AI response
  Future<void> _sendMessage(ChatMessage chatMessage) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    chatProvider.addMessage(chatMessage);

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
      final responseText = response?.text ?? '';

      print('AI Response: $responseText');

      // Check if the AI response contains a JSON recipe
      final recipeJson = extractJsonRecipe(responseText);

      ChatMessage aiMessage = ChatMessage(
        user: geminiUser,
        createdAt: DateTime.now(),
        text: recipeJson == null
            ? responseText
            : responseText.replaceAll(json.encode(recipeJson), ''),
        customProperties: {"isAIMessage": true, "jsonRecipe": recipeJson},
        quickReplies: _getQuickReplies(),
      );

      chatProvider.addMessage(aiMessage);
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  // Pick and send media messages (e.g., images)
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

  // Get quick reply options for the chat
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

  // Navigate to the AddRecipeForm screen with the parsed JSON recipe
  void _navigateToAddRecipeForm(
      BuildContext context, Map<String, dynamic>? recipeJson) {
    if (recipeJson != null) {
      Recipe recipe = Recipe.fromJson(recipeJson);
      print('Navigating to AddRecipeForm with recipe: $recipe');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddRecipeForm(
            initialRecipe: recipe,
          ),
        ),
      );
    }
  }
}
