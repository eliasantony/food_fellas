import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:food_fellas/providers/chatProvider.dart';
import 'package:food_fellas/src/models/aimodel_config.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:food_fellas/src/widgets/chatRecipeCard.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

// Define your users
ChatUser currentUser = ChatUser(id: "0", firstName: "User");
ChatUser geminiUser = ChatUser(
  id: "1",
  firstName: "FoodFella Assist",
  profileImage:
      "https://seeklogo.com/images/G/google-gemini-logo-A5787B2669-seeklogo.com.png",
);

// Helper function to extract and parse the JSON code block
Map<String, dynamic>? extractJsonRecipe(String text) {
  try {
    // Regular expression to find JSON code blocks
    final codeBlockRegExp =
        RegExp(r'```json\s*(\{[\s\S]*?\})\s*```', multiLine: true);
    final match = codeBlockRegExp.firstMatch(text);
    if (match != null) {
      String? jsonString = match.group(1);
      if (jsonString != null) {
        // Preprocess the JSON string to replace fractions with decimal equivalents
        jsonString = jsonString.replaceAllMapped(
          RegExp(r'(\d+)/(\d+)'),
          (match) {
            final numerator = int.parse(match.group(1)!);
            final denominator = int.parse(match.group(2)!);
            return (numerator / denominator).toString();
          },
        );

        final Map<String, dynamic> decoded = json.decode(jsonString);
        if (decoded.containsKey('title') &&
            decoded.containsKey('description') &&
            decoded.containsKey('ingredients') &&
            decoded.containsKey('cookingSteps')) {
          print("Decoded Recipe: $decoded");
          return decoded;
        }
      }
    }
  } catch (e) {
    print('Error parsing JSON: $e');
    // Ignore parsing errors, just return null
  }
  return null;
}

// Function to remove the JSON code block from the message text
String removeJsonCodeBlock(String text) {
  final codeBlockRegExp =
      RegExp(r'```json\s*(\{[\s\S]*?\})\s*```', multiLine: true);
  return text.replaceAll(codeBlockRegExp, '');
}

// Function to extract options from a text message
List<String> extractOptions(String text) {
  // final regex = RegExp(r'^\d+\.\s*(?:\S+\s)?\*\*(.*?)\*\*', multiLine: true);
  final regex = RegExp(r'^\d+\.\s*(.+)$', multiLine: true);
  final matches = regex.allMatches(text);

  // Print each match for debugging
  for (var match in matches) {
    print('Match: ${match.group(1)}');
  }

  return matches.map((match) => match.group(1)?.trim() ?? '').toList();
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  bool isLoading = false;
  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    bool isChatEmpty = chatProvider.messages.isEmpty;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("FoodFellas AI Assistant"),
      ),
      body: Stack(children: [
        Column(
          children: [
            if (isChatEmpty)
              // Display Quick Replies at the top
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 128.0, 8.0, 8.0),
                child: Column(
                  //spacing: 8,
                  children: _getQuickReplies().map((quickReply) {
                    return ChoiceChip(
                      label: Text(quickReply.title ?? ''),
                      selected: false,
                      onSelected: (selected) {
                        _onQuickReply(quickReply);
                      },
                    );
                  }).toList(),
                ),
              ),
            Expanded(
              child: DashChat(
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
                      final recipeJson =
                          message.customProperties?['jsonRecipe'];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Display the message text (without JSON)
                          if ((message.text ?? '').trim().isNotEmpty)
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
                          // Display the RecipeCard
                          ChatRecipeCard(
                            recipe: recipeJson,
                            onAddRecipe: () {
                              _navigateToAddRecipeForm(context, recipeJson);
                            },
                          ),
                        ],
                      );
                    } else {
                      // Regular message display
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
            ),
          ],
        ),
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Lottie.asset('lib/assets/lottie/loadingAnim.json'),
            ),
          ),
      ]),
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

      // Extract the JSON recipe from the response
      final recipeJson = extractJsonRecipe(responseText);
      // Remove the JSON code block from the response text
      final displayText = removeJsonCodeBlock(responseText).trim();

      // **Extract options from the AI's response**
      List<String> extractedOptions = extractOptions(displayText);
      List<QuickReply> dynamicQuickReplies = [];

      if (extractedOptions.isNotEmpty) {
        // Create quick replies from the extracted options
        dynamicQuickReplies = extractedOptions.map((option) {
          return QuickReply(
            title: option,
            value: option,
          );
        }).toList();
      }

      ChatMessage aiMessage = ChatMessage(
        user: geminiUser,
        createdAt: DateTime.now(),
        text: displayText,
        customProperties: {"isAIMessage": true, "jsonRecipe": recipeJson},
        quickReplies: dynamicQuickReplies.isNotEmpty ? dynamicQuickReplies : null,
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

  void _navigateToAddRecipeForm(
      BuildContext context, Map<String, dynamic>? recipeJson) async {
    if (recipeJson != null) {
      setState(() {
        isLoading = true;
      });

      Recipe recipe = Recipe.fromJson(recipeJson);
      recipe.createdByAI = true; // Set the AI-created flag

      // Check and add missing ingredients
      await _checkAndAddIngredients(recipe);

      setState(() {
        isLoading = false;
      });

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

  Future<void> _checkAndAddIngredients(Recipe recipe) async {
    final ingredientsCollection =
        FirebaseFirestore.instance.collection('ingredients');

    for (var recipeIngredient in recipe.ingredients) {
      String ingredientName = recipeIngredient.ingredient.ingredientName;

      // Check if ingredient exists
      QuerySnapshot snapshot = await ingredientsCollection
          .where('ingredientName', isEqualTo: ingredientName)
          .get();

      if (snapshot.docs.isEmpty) {
        // Ingredient doesn't exist, add it with approved: false
        await ingredientsCollection.add({
          'ingredientName': ingredientName,
          'category': recipeIngredient.ingredient.category,
          'approved': false,
        });
      }
    }
  }
}
