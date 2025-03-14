import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:food_fellas/providers/bottomNavBarProvider.dart';
import 'package:food_fellas/providers/chatProvider.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/models/aimodel_config.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/services/analytics_service.dart';
import 'package:food_fellas/src/utils/aiTokenUsage.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:food_fellas/src/views/addRecipeForm/feedback_dialog.dart';
import 'package:food_fellas/src/views/guestUserScreen.dart';
import 'package:food_fellas/src/views/subscriptionScreen.dart';
import 'package:food_fellas/src/widgets/chatRecipeCard.dart';
import 'package:food_fellas/src/widgets/feedbackModal.dart';
import 'package:food_fellas/src/widgets/recipeCard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// Define your users
ChatUser currentUser = ChatUser(id: "0", firstName: "User");
ChatUser geminiUser = ChatUser(
  id: "1",
  firstName: "FoodFellas AI Assist",
  profileImage:
      "https://firebasestorage.googleapis.com/v0/b/food-fellas-rts94q.appspot.com/o/FoodFellas_Assistant.png?alt=media&token=a6f11228-1b4f-42f7-9dbb-5844e3093431",
);

String cleanJsonString(String jsonString) {
  // Remove any trailing commas inside objects or arrays (JSON doesn't allow them)
  jsonString = jsonString.replaceAll(RegExp(r',\s*([\]}])'), '');

  // Remove invisible control characters (can corrupt JSON)
  jsonString = jsonString.replaceAll(RegExp(r'[\u0000-\u001F]'), '');

  // Remove a comma right before the closing square bracket of the "tags" array
  jsonString = jsonString.replaceAll(RegExp(r',\s*\]'), ']');

  // Ensure proper formatting
  jsonString = jsonString.trim();

  return jsonString;
}

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

        final cleanedJsonString = cleanJsonString(jsonString);
        final Map<String, dynamic> decoded = json.decode(cleanedJsonString);
        if (decoded.containsKey('title') &&
            decoded.containsKey('description') &&
            decoded.containsKey('ingredients') &&
            decoded.containsKey('cookingSteps') &&
            decoded.containsKey('tags')) {
          return decoded;
        } else {
          debugPrint("Invalid JSON format: Missing required fields.");
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

bool isValidRecipeJson(Map<String, dynamic> json) {
  // Check that required keys exist and are of the expected types.
  if (!json.containsKey('title') ||
      !json.containsKey('description') ||
      !json.containsKey('ingredients') ||
      !json.containsKey('cookingSteps') ||
      !json.containsKey('tags')) {
    return false;
  }

  // You might also want to validate the structure of ingredients.
  final ingredients = json['ingredients'];
  if (ingredients is! List) return false;
  for (var ingredient in ingredients) {
    // Expecting each ingredient to be a Map with a nested structure.
    if (ingredient is! Map ||
        ingredient['ingredient'] == null ||
        !(ingredient['ingredient'] is Map) ||
        !ingredient['ingredient'].containsKey('ingredientName')) {
      return false;
    }
  }
  // Additional validations can be added here.

  return true;
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  bool isLoading = false;
  bool preferencesEnabled = true;
  List<ChatUser> typingUsers = [];
  late FocusNode _chatFocusNode;

  @override
  void initState() {
    super.initState();
    _chatFocusNode = FocusNode();
    _chatFocusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    // Check if the text field gained focus and if the user is a guest
    final currentUser = FirebaseAuth.instance.currentUser;
    bool isGuestUser = currentUser == null || currentUser.isAnonymous;
    if (_chatFocusNode.hasFocus && isGuestUser) {
      // Immediately unfocus the input
      _chatFocusNode.unfocus();
      // Show the sign up / log in prompt
      _showSignUpPrompt();
    }
  }

  void _showSignUpPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create an Account"),
        content: const Text(
          "To chat with AI, please log in or sign up for an account.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text("Log In"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacementNamed(context, '/signup');
            },
            child: const Text("Sign Up"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatFocusNode.dispose();
    super.dispose();
  }

  void _addTypingUser(ChatUser user) {
    setState(() {
      if (!typingUsers.contains(user)) {
        typingUsers.add(user);
      }
    });
  }

  void _removeTypingUser(ChatUser user) {
    setState(() {
      typingUsers.remove(user);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    bool isChatEmpty = chatProvider.messages.isEmpty;

    final currentFirebaseUser = FirebaseAuth.instance.currentUser;
    bool isGuestUser =
        currentFirebaseUser == null || currentFirebaseUser.isAnonymous;

    if (isGuestUser) {
      return GuestUserScreen(
          title: "AI Chat",
          message: "Sign up or log in to chat with our AI Assistant.");
    }

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom > 0
        ? MediaQuery.of(context).viewInsets.bottom
        : (kBottomNavigationBarHeight - 50);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) {
            if (Theme.of(context).brightness == Brightness.dark) {
              return LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            } else {
              return LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            }
          },
          child: Text(
            "AI Chef",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Reload Last Message',
            onPressed: _reloadLastAIMessages,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'preferences') {
                _togglePreferences();
              } else if (value == 'feedback') {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return FeedbackModal();
                  },
                );
              } else if (value == 'clear_chat') {
                _confirmClearChat();
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
                  child: Row(
                    children: [
                      Icon(Icons.feedback),
                      SizedBox(width: 8),
                      Text('Provide Feedback'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'clear_chat',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services_outlined),
                      SizedBox(width: 8),
                      Text('Clear Chat'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
        leading: GestureDetector(
          onTap: () {
            Provider.of<BottomNavBarProvider>(context, listen: false)
                .setIndex(0);
          },
          child: Padding(
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
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Stack(children: [
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
                  readOnly: isGuestUser,
                  inputOptions: InputOptions(
                    focusNode: _chatFocusNode,
                    inputTextStyle: TextStyle(
                      color: Colors.black,
                    ),
                    maxInputLength: 500,
                    sendOnEnter: true,
                    sendButtonBuilder: defaultSendButton(
                        color: Theme.of(context).colorScheme.primary,
                        padding: EdgeInsets.fromLTRB(16, 0, 0, 16)),
                    /* trailing: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: IconButton(
                            onPressed: _sendMediaMessage,
                            icon: const Icon(Icons.image),
                          ),
                        )
                      ] */
                  ),
                  typingUsers: [...typingUsers],
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
                        ChatMessage? previousMessage,
                        ChatMessage? nextMessage) {
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
                        ChatMessage? previousMessage,
                        ChatMessage? nextMessage) {
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
                                AnalyticsService.logEvent(
                                    name: "ai_chat_recipe_started");
                                _navigateToAddRecipeForm(context, recipeJson);
                              },
                            ),
                          ],
                        );
                      } else if (message
                              .customProperties?['similarRecipeDoc'] !=
                          null) {
                        final doc =
                            message.customProperties!['similarRecipeDoc'];
                        return RecipeCard(recipeId: doc['id'], big: false);
                      } else {
                        // Regular message display
                        return MarkdownBody(
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
      ),
    );
  }

  void _togglePreferences() {
    setState(() {
      preferencesEnabled = !preferencesEnabled;
    });
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.reinitializeModel(preferencesEnabled);
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
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    final isSubscribed = userProvider.userData?['subscribed'] ?? false;
    final isAdmin = userProvider.userData?['isAdmin'] ?? false;

    // Estimate token usage; adjust your logic as needed.
    int estimatedTokens = chatMessage.text.length ~/ 4; // rough estimate

    // Check daily usage before sending.
    bool allowed = await canUseAiChat(userId, isAdmin, isSubscribed, estimatedTokens);
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "You've reached your daily AI Chat limit. Upgrade to Premium for more usage."),
          action: SnackBarAction(
            label: "Upgrade",
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SubscriptionScreen()));
            },
          ),
        ),
      );
      return;
    }

    // If allowed, update the daily usage and proceed.
    await updateDailyTokenUsage(userId, estimatedTokens);

    // Add the user's message to the UI
    chatProvider.addMessages([chatMessage], saveToFirestore: true);

    _addTypingUser(geminiUser);
    try {
      //setState(() => isLoading = true);
      int startTime = DateTime.now().millisecondsSinceEpoch; // Start timing
      // 1) Send a single request to the AI, retrieve response + usage

      final response = await chatProvider.chatInstance?.sendMessage(
        Content.text(chatMessage.text),
      );
      int endTime = DateTime.now().millisecondsSinceEpoch; // End timing
      int responseTime = endTime - startTime;

      if (response == null) {
        throw Exception('No response from AI');
      }
      final responseText = response.text ?? '';

      AnalyticsService.logEvent(
        name: "ai_chat_response_time",
        parameters: {
          "duration_ms": responseTime,
          "message_length": chatMessage.text.length,
        },
      );

      // 2) Track usage tokens
      final usedTokens = response.usageMetadata?.totalTokenCount ?? 0;
      print('Used tokens: $usedTokens');

      // 4) Extract JSON recipe
      final recipeJson = extractJsonRecipe(responseText);

      // 5) Fuzzy search if we found a new recipe
      List<Map<String, dynamic>> foundSimilarRecipes = [];
      if (recipeJson != null) {
        final title = recipeJson['title'] ?? '';
        final description = recipeJson['description'] ?? '';
        final ingredientsList =
            recipeJson['ingredients'] as List<dynamic>? ?? [];

        final List<String> ingredientNames = ingredientsList.map<String>((ing) {
          return ing['ingredient']['ingredientName'] as String? ?? '';
        }).toList();

        // fetchFuzzyRecipes is from your SearchProvider
        await searchProvider.fetchFuzzyRecipes(
          title: title,
          description: description,
          ingredients: ingredientNames,
        );

        foundSimilarRecipes = searchProvider.similarRecipes;
      }

      // 7) Remove the JSON from the final display text
      final displayText = removeJsonCodeBlock(responseText).trim();

      // 8) Extract conversation options for QuickReplies (like you already do)
      List<String> extractedOptions = extractOptions(displayText);
      List<QuickReply> dynamicQuickReplies = extractedOptions.map((option) {
        return QuickReply(title: option, value: option);
      }).toList();

      // 9) Build the final AI message
      ChatMessage aiMessage = ChatMessage(
        user: geminiUser,
        createdAt: DateTime.now(),
        text: displayText,
        quickReplies:
            dynamicQuickReplies.isNotEmpty ? dynamicQuickReplies : null,
        customProperties: {
          "isAIMessage": true,
          "jsonRecipe": recipeJson, // This will trigger your ChatRecipeCard
        },
      );

      // 10) Add the AI message to the chat
      chatProvider.addMessages([aiMessage], saveToFirestore: true);

      if (foundSimilarRecipes.isNotEmpty) {
        // 6) Show a separate chat message presenting the found recipes
        ChatMessage foundMessage = ChatMessage(
          user: geminiUser,
          createdAt: DateTime.now(),
          text: (foundSimilarRecipes.length > 1)
              ? "**I found some recipes that seem similar!**\n\n"
                  "Here they are:"
              : "**I found a recipe that seems similar!**\n\n" "Here it is:",
          customProperties: {
            "isAIMessage": true,
            // We could store them if you want or just show them
          },
        );
        chatProvider.addMessages([foundMessage], saveToFirestore: true);

        // Show them as small cards (or your own layout).
        // For example, we can loop each found recipe and create a message:
        for (var simRecipe in foundSimilarRecipes) {
          ChatMessage simRecipeMsg = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: simRecipe['title'] ?? 'Untitled', // or empty
            // or store the entire doc to display in a custom widget
            customProperties: {
              "isAIMessage": true,
              "similarRecipeDoc": simRecipe,
            },
          );
          chatProvider.addMessages([simRecipeMsg], saveToFirestore: true);
        }
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      _removeTypingUser(geminiUser);
      //setState(() => isLoading = false);
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
      recipe.source = 'ai_chat';

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

  Future<void> _reloadLastAIMessages() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    setState(() {
      isLoading = true;
    });

    print('Reloading last AI messages...');

    try {
      List<ChatMessage> lastAIMessages = await chatProvider.getLastAIMessages();
      if (lastAIMessages.isNotEmpty) {
        chatProvider.addMessages(lastAIMessages,
            saveToFirestore: false); // Do not save
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Last AI messages reloaded.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No previous AI messages found.')),
        );
      }
    } catch (e) {
      print('Error reloading last AI messages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reload the last AI messages.')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Shows a confirmation dialog before clearing the chat.
  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear Chat'),
          content: Text(
              'Are you sure you want to clear the chat and start a new conversation?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _clearChat(); // Proceed to clear the chat
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text('Clear',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        );
      },
    );
  }

  /// Clears the chat by invoking the provider's clearChat method.
  void _clearChat() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.clearChat();

    // Optionally, reset other UI states or inform the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chat cleared. Starting a new conversation.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
