import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:food_fellas/providers/chatProvider.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:food_fellas/src/models/aimodel_config2.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:food_fellas/src/widgets/chatRecipeCard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// Define your users
ChatUser currentUser = ChatUser(id: "0", firstName: "User");
ChatUser geminiUser = ChatUser(
  id: "1",
  firstName: "FoodFella Assist",
  profileImage:
      "https://firebasestorage.googleapis.com/v0/b/food-fellas-rts94q.appspot.com/o/FoodFellas_Assistant.png?alt=media&token=a6f11228-1b4f-42f7-9dbb-5844e3093431",
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
            decoded.containsKey('cookingSteps') &&
            decoded.containsKey('tags')) {
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

Map<String, dynamic>? extractPreviewJson(String text) {
  try {
    final codeBlockRegExp =
        RegExp(r'```json\s*(\{[\s\S]*?\})\s*```', multiLine: true);
    final match = codeBlockRegExp.firstMatch(text);
    if (match != null) {
      String? jsonString = match.group(1);
      if (jsonString != null) {
        final decoded = json.decode(jsonString);
        if (decoded.containsKey('title') &&
            decoded.containsKey('description') &&
            decoded.containsKey('ingredients')) {
          print(decoded);
          return decoded;
        }
      }
    }
  } catch (e) {
    print('Error parsing preview JSON: $e');
  }
  return null;
}

// Function to remove the JSON code block from the message text
String removeJsonCodeBlock(String text) {
  final codeBlockRegExp =
      RegExp(r'```json\s*(\{[\s\S]*?\})\s*```', multiLine: true);
  return text.replaceAll(codeBlockRegExp, '');
}

List<String> extractOptions(String text) {
  final regex = RegExp(
    r'^\s*\d+\.\s*(?:([^\s]+)\s+)?\*\*(.*?)\*\*',
    multiLine: true,
  );
  final matches = regex.allMatches(text);

  List<String> options = [];
  for (var match in matches) {
    final emoji = match.group(1)?.trim() ?? '';
    final title = match.group(2)?.trim() ?? '';
    final option = '${emoji.isNotEmpty ? emoji + ' ' : ''}$title';
    options.add(option);
  }

  return options;
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  bool isLoading = false;
  bool preferencesEnabled = true;

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    bool isChatEmpty = chatProvider.messages.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "FoodFellas' AI Chef",
          style: GoogleFonts.poppins(
            color: Color(0xFF116131),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'preferences') {
                _togglePreferences();
              } else if (value == 'feedback') {
                _openFeedbackForm();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'preferences',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Enable Preferences'),
                      Checkbox(
                        value: preferencesEnabled,
                        onChanged: (bool? newValue) {
                          Navigator.pop(context); // Close the menu
                          _togglePreferences();
                        },
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'feedback',
                  child: Text('Provide Feedback'),
                ),
              ];
            },
          ),
        ],
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 4.0, 0.0, 4.0),
          child: SizedBox(
            width: 8,
            height: 8,
            child: Image.asset(
              'lib/assets/brand/hat.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
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
                      label: Text(
                        quickReply.title ?? '',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
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
                inputOptions: InputOptions(
                    inputTextStyle: TextStyle(
                      color: Colors.black,
                    ),
                    sendOnEnter: true,
                    trailing: [
                      IconButton(
                        onPressed: _sendMediaMessage,
                        icon: const Icon(Icons.image),
                      )
                    ]),
                quickReplyOptions: QuickReplyOptions(
                  quickReplyTextStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  quickReplyStyle: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  onTapQuickReply: _onQuickReply,
                ),
                messageOptions: MessageOptions(
                  messageDecorationBuilder: (ChatMessage message,
                      ChatMessage? previousMessage, ChatMessage? nextMessage) {
                    return BoxDecoration(
                      color: message.customProperties?['isAIMessage'] == true
                          ? Colors.greenAccent.withOpacity(0.3)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? const Color.fromARGB(255, 163, 163, 163)
                                  .withOpacity(0.6)
                              : const Color.fromARGB(255, 163, 163, 163)
                                  .withOpacity(0.1)),
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
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                strong: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                blockquote: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                          ),
                          strong: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                          ),
                          blockquote: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }
                  },
                ),
                currentUser: currentUser,
                onSend: _sendMessage,
                messages: chatProvider.messages.reversed.toList(),
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

  void _togglePreferences() {
    setState(() {
      preferencesEnabled = !preferencesEnabled;
    });
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.reinitializeModel(preferencesEnabled);
  }

  void _openFeedbackForm() {
    showDialog(
      context: context,
      builder: (context) {
        String feedback = '';
        String selectedCategory = 'Suggestion';
        int rating = 5;
        final _formKey = GlobalKey<FormState>();

        return AlertDialog(
          title: Text('Provide Feedback'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Feedback Categories Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'Urgent',
                      'Bug Report',
                      'Suggestion',
                      'Praise',
                      'Other',
                    ].map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        selectedCategory = value;
                      }
                    },
                  ),
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Rate your experience:'),
                  ),
                  SizedBox(height: 8),
                  // Rating System
                  RatingBar.builder(
                    initialRating: rating.toDouble(),
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: false,
                    itemCount: 5,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                    itemBuilder: (context, _) => const Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    onRatingUpdate: (newRating) {
                      setState(() {
                        rating = newRating.toInt();
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  // Multi-line Feedback TextField
                  TextFormField(
                    maxLines: 5,
                    minLines: 3,
                    onChanged: (value) {
                      feedback = value;
                    },
                    decoration: InputDecoration(
                      labelText: 'Your Feedback',
                      hintText: 'Enter detailed feedback here...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your feedback.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.of(context).pop();
                  _submitFeedback(feedback, selectedCategory, rating);
                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _submitFeedback(String feedback, String category, int rating) {
    FirebaseFirestore.instance.collection('feedback').add({
      'feedback': feedback,
      'category': category,
      'rating': rating,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
    });

    // For demonstration, we'll show a success message.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Thank you for your feedback!'),
        duration: Duration(seconds: 2),
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
      final responseText = await chatProvider.sendMessageToAI(chatMessage.text);

      print('AI Response: $responseText');

      // Extract the JSON preview recipe from the response
      final previewJson = extractPreviewJson(responseText);
      if (previewJson != null) {
        final searchProvider =
            Provider.of<SearchProvider>(context, listen: false);
        final title = previewJson['title'];
        final description = previewJson['description'];
        final ingredients = List<String>.from(previewJson['ingredients']);

        // Call SearchProvider to fetch similar recipes
        await searchProvider.fetchFuzzyRecipes(
          title: title,
          description: description,
          ingredients: ingredients,
        );

        if (searchProvider.similarRecipes.isNotEmpty) {
          String foundRecipesText = "Here are some similar recipes I found:\n";
          for (var recipe in searchProvider.similarRecipes) {
            foundRecipesText +=
                "- **${recipe['title']}**: ${recipe['description']}\n";
          }
          foundRecipesText +=
              "Do you want to use one of these, or should I create a new recipe for you?";

          print('Found similar recipes: $foundRecipesText');
        }
      }

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
        quickReplies:
            dynamicQuickReplies.isNotEmpty ? dynamicQuickReplies : null,
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
        text:
            "Try to create a recipe based on the ingredients you can see in this image!",
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
      // Save the recipeJson to a local JSON file
      // final directory = await getApplicationDocumentsDirectory();
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
