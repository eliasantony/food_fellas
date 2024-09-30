import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    selectedTags = widget.recipe.tags?.toSet() ?? {};
    _fetchTags();
  }

  Future<void> _fetchTags() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('tags').get();
    Map<String, List<Tag>> tempCategorizedTags = {};

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      Tag tag = Tag.fromMap(data, doc.id);

      if (!tempCategorizedTags.containsKey(tag.category)) {
        tempCategorizedTags[tag.category] = [];
      }

      tempCategorizedTags[tag.category]!.add(tag);
    }

    setState(() {
      categorizedTags = tempCategorizedTags;
    });
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
