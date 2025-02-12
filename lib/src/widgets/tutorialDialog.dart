import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> shouldShowTutorial() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('tutorial_shown') ?? true;
}

Future<void> setTutorialShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('tutorial_shown', false);
}

void checkAndShowTutorial(BuildContext context) async {
  if (await shouldShowTutorial()) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showTutorialDialog(context);
    });
  }
}

void showTutorialDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return TutorialDialog();
    },
  );
}

class TutorialDialog extends StatefulWidget {
  @override
  _TutorialDialogState createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  PageController _pageController = PageController();
  int _currentPage = 0;

  List<Map<String, String>> tutorialPages = [
    {
      'gif': 'lib/assets/tutorialGifs/AIChat.gif',
      'title': '🤖 AI-Powered Recipe Suggestions',
      'text':
          'Need inspiration?\nTell our AI your thoughts or what ingredients you have, and it will suggest a recipe in seconds!',
    },
    {
      'gif': 'lib/assets/tutorialGifs/GenerateImage.gif',
      'title': '🎨 AI Recipe Image Generator',
      'text':
          'Missing an image for your recipe?\nOur AI creates stunning food visuals for you!',
    },
    {
      'gif': 'lib/assets/tutorialGifs/ImageToRecipe.gif',
      'title': '📸 AI Recipe Recognition',
      'text':
          'Upload a food photo, describe it briefly, and let our AI generate a recipe for you!',
    },
    {
      'gif': 'lib/assets/tutorialGifs/AddRecipeForm.gif',
      'title': '📋 Add Your Own Recipes',
      'text':
          'Easily add and customize your own delicious recipes to share with the FoodFellas community!',
    },
    {
      'gif': 'lib/assets/tutorialGifs/Feedback.gif',
      'title': '💡 Help Us Improve!',
      'text':
          'Have suggestions?\nGo to **Profile → Settings → Give Feedback** and share your thoughts!',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.8,
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: tutorialPages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return StatefulBuilder(builder: (context, setState) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(8.0, 24.0, 8.0, 0.0),
                          child: Text(
                            tutorialPages[index]['title']!,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 24),
                        Expanded(
                          flex: 5,
                          child: Image.asset(
                            tutorialPages[index]['gif']!,
                            key: ValueKey(
                                _currentPage), // Restart GIF on page change
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: 24),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 12.0),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: _parseText(tutorialPages[index]['text']!),
                            ),
                          ),
                        ),
                      ],
                    );
                  });
                },
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () async {
                    if (await shouldShowTutorial()) {
                      bool? confirmSkip = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text("Skip Tutorial?"),
                            content: Text(
                                "Are you sure you want to skip? You can revisit this tutorial in Settings later."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text("Skip"),
                              ),
                            ],
                          );
                        },
                      );
                      if (confirmSkip == true) {
                        Navigator.pop(context);
                        await setTutorialShown();
                      }
                    } else {
                      Navigator.pop(context);
                      await setTutorialShown();
                    }
                  },
                  child: Text("Skip"),
                ),
                // ...existing code...
                Row(
                  children: List.generate(
                    tutorialPages.length,
                    (index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            index == _currentPage ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (_currentPage == tutorialPages.length - 1) {
                      await setTutorialShown();
                      Navigator.pop(context);
                    } else {
                      _pageController.nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(_currentPage == tutorialPages.length - 1
                      ? "Finish"
                      : "Next"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  /// Parses text and makes words between ** bold
  TextSpan _parseText(String text) {
    List<TextSpan> spans = [];
    RegExp exp = RegExp(r'\*\*(.*?)\*\*');
    Iterable<RegExpMatch> matches = exp.allMatches(text);

    int currentIndex = 0;
    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(fontWeight: FontWeight.bold),
      ));
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return TextSpan(
        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        children: spans);
  }
}
