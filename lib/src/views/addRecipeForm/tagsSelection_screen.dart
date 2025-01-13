import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/providers/tagProvider.dart';
import 'package:food_fellas/src/models/autoTagSelection_config.dart';
import 'package:food_fellas/src/utils/aiTokenUsage.dart';
import 'package:provider/provider.dart';
import '../../models/recipe.dart';
import '../../models/tag.dart';

class TagsSelectionPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;
  final GlobalKey<FormState> formKey;

  TagsSelectionPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
    required this.formKey,
  }) : super(key: key);

  @override
  _TagsSelectionPageState createState() => _TagsSelectionPageState();
}

class _TagsSelectionPageState extends State<TagsSelectionPage> {
  Map<String, List<Tag>> categorizedTags = {};
  Set<Tag> selectedTags = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeTags();
  }

  void _initializeTags() async {
    final tagProvider = Provider.of<TagProvider>(context, listen: false);
    await tagProvider.fetchTags();
    List<Tag> allTags = tagProvider.tags;

    // Prepare a set to hold the initial selected tags
    Set<Tag> initialSelectedTags = {};

    // Collect tag names to match from either aiTagNames or recipe.tags
    List<String> tagNamesToMatch = [];

    if (widget.recipe.aiTagNames != null &&
        widget.recipe.aiTagNames!.isNotEmpty) {
      tagNamesToMatch = widget.recipe.aiTagNames!;
    } else if (widget.recipe.tags.isNotEmpty) {
      tagNamesToMatch = widget.recipe.tags.map((tag) => tag.name).toList();
    }

    // Match tags by name and collect them from allTags
    for (String tagName in tagNamesToMatch) {
      Tag? matchedTag = _findTagByName(tagName, allTags);
      if (matchedTag != null) {
        initialSelectedTags.add(matchedTag);
      }
    }

    // Categorize tags
    Map<String, List<Tag>> tempCategorizedTags = {};

    for (var tag in allTags) {
      if (!tempCategorizedTags.containsKey(tag.category)) {
        tempCategorizedTags[tag.category] = [];
      }
      tempCategorizedTags[tag.category]!.add(tag);
    }

    setState(() {
      categorizedTags = tempCategorizedTags;
      selectedTags = initialSelectedTags;
    });
  }

  Tag? _findTagByName(String tagName, List<Tag> tags) {
    for (var tag in tags) {
      if (tag.name.toLowerCase() == tagName.toLowerCase()) {
        return tag;
      }
    }
    return null;
  }

  Future<void> _autoSelectTagsWithAI() async {
    setState(() {
      isLoading = true;
    });

    try {
      final model = getAutoTagSelection(
          recipe: widget.recipe, categorizedTags: categorizedTags);
      final prompt =
          '''Select as many relevant tags as possible based on this recipe:
        ${widget.recipe.toJson()} 
        Available tags: ${categorizedTags.keys.join(", ")}.
        Return just the tag names seperated by a comma.''';

      final currentUser = FirebaseAuth.instance.currentUser;
      if (await checkLimitExceeded(currentUser!.uid)) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You have exceeded your monthly AI usage limit. Please try again next month.',
            ),
          ),
        );
        return;
      }

      final response = await model?.generateContent([Content.text(prompt)]);
      // 2) Track usage tokens
      final usedTokens = response?.usageMetadata?.totalTokenCount ?? 0;
      print('Used tokens: $usedTokens');

      // 3) Store or update user’s total tokens
      await updateUserTokenUsage(currentUser.uid, usedTokens);
      final responseText = response?.text ?? '';
      final tagNames =
          responseText.split(',').map((tag) => tag.trim()).toList() ?? [];

      // Update selected tags
      final allTags = Provider.of<TagProvider>(context, listen: false).tags;
      Set<Tag> newSelectedTags = {};
      for (var tagName in tagNames) {
        Tag? tag = _findTagByName(tagName, allTags);
        if (tag != null) {
          newSelectedTags.add(tag);
        }
      }

      setState(() {
        selectedTags = newSelectedTags;
        isLoading = false;
      });

      widget.onDataChanged('tags', selectedTags.toList());
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Try to select as many relevant tags as possible!',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.left,
          ),
        ),
        Expanded(
          child: Form(
            key: widget.formKey,
            child: ListView(
              padding: EdgeInsets.all(16),
              children: categorizedTags.entries.map((entry) {
                String category = entry.key;
                List<Tag> tags = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: tags.map((tag) {
                        bool isSelected = selectedTags.contains(tag);
                        return FilterChip(
                          label: Text('${tag.icon} ${tag.name}'),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.removeWhere(
                                    (selectedTag) => selectedTag.id == tag.id);
                              }
                              widget.onDataChanged(
                                  'tags', selectedTags.toList());
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        Center(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : _autoSelectTagsWithAI,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(horizontal: 30),
            ),
            icon: isLoading
                ? CircularProgressIndicator(color: Colors.white)
                : Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 16,
                  ),
            label: isLoading
                ? SizedBox.shrink()
                : Text(
                    'Auto-Select Tags with AI',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                  ),
          ),
        ),
      ],
    );
  }
}
