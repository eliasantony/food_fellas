import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/providers/tagProvider.dart';
import 'package:provider/provider.dart';
import '../../models/recipe.dart';
import '../../models/tag.dart';
import 'package:food_fellas/providers/tagProvider.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeTags();
  }

  void _initializeTags() async {
    final tagProvider = Provider.of<TagProvider>(context, listen: false);
    await tagProvider.fetchTags();

    List<Tag> allTags = tagProvider.tags;

    // Perform matching using aiTagNames
    Set<Tag> initialSelectedTags = {};

    if (widget.recipe.aiTagNames != null &&
        widget.recipe.aiTagNames!.isNotEmpty) {
      for (String tagName in widget.recipe.aiTagNames!) {
        Tag? matchedTag = _findTagByName(tagName, allTags);
        if (matchedTag != null) {
          initialSelectedTags.add(matchedTag);
        }
      }
    } else if (widget.recipe.tags.isNotEmpty) {
      // If tags are already set (e.g., user edited), use them
      initialSelectedTags = widget.recipe.tags.toSet();
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

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: categorizedTags.entries.map((entry) {
          String category = entry.key;
          List<Tag> tags = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category, style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: tags.map((tag) {
                  bool isSelected = selectedTags
                      .any((selectedTag) => selectedTag.id == tag.id);
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
                        widget.onDataChanged('tags', selectedTags.toList());
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
    );
  }
}
