import 'package:flutter/material.dart';
import 'package:food_fellas/providers/tagProvider.dart';
import 'package:food_fellas/src/views/ingredientsFilter_screen.dart';
import 'package:provider/provider.dart';

class FilterModal extends StatefulWidget {
  final Map<String, dynamic> initialFilters;
  final Function(Map<String, dynamic>) onApply;

  FilterModal({required this.initialFilters, required this.onApply});

  @override
  _FilterModalState createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal> {
  Map<String, dynamic> filters = {};
  bool showAllTags = false;
  Map<String, List<Map<String, dynamic>>> categorizedTags = {};

  @override
  void initState() {
    super.initState();
    filters = Map.from(widget.initialFilters);
  }

  @override
  Widget build(BuildContext context) {
    final tagsProvider = Provider.of<TagProvider>(context);
    if (!tagsProvider.isLoaded) {
      tagsProvider.fetchTags();
      return Center(child: CircularProgressIndicator());
    }
    // Categorize tags
    categorizedTags =
        _categorizeTags(tagsProvider.tags.map((tag) => tag.toMap()).toList());

    // Limit the number of tags shown when showAllTags is false
    Map<String, List<Map<String, dynamic>>> tagsToShow =
        showAllTags ? categorizedTags : _limitTags(categorizedTags, 12);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRatingFilter(),
            _buildCookingTimeFilter(),
            _buildTagsFilter(tagsToShow),
            _buildIngredientFilter(),
            _buildCreatedByAIFilter(),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Call the onApply with the updated filters
                widget.onApply(filters);
              },
              icon: Icon(
                Icons.filter_alt,
                color: Theme.of(context).canvasColor,
              ),
              label: Text('Apply Filters',
                  style: TextStyle(color: Theme.of(context).canvasColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingFilter() {
    double minRating = filters['averageRating'] ?? 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Minimum Rating:'),
            Expanded(child: SizedBox()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(minRating.toStringAsFixed(1)),
                  SizedBox(width: 4),
                  Icon(Icons.star, color: Colors.amber),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: minRating,
                min: 0,
                max: 5,
                divisions: 10,
                label: minRating.toStringAsFixed(1),
                onChanged: (value) {
                  setState(() {
                    filters['averageRating'] = value;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCookingTimeFilter() {
    double maxCookingTime = filters['cookingTimeInMinutes'] ?? 120;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Maximum Cooking Time:'),
            Expanded(child: SizedBox()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(maxCookingTime.toInt().toString() + ' mins'),
                  SizedBox(width: 4),
                  Icon(Icons.timer_outlined),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: maxCookingTime.toDouble(),
                min: 0,
                max: 120,
                divisions: 12,
                label: maxCookingTime.toStringAsFixed(1),
                onChanged: (value) {
                  setState(() {
                    filters['cookingTimeInMinutes'] = value;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Map<String, List<Map<String, dynamic>>> _categorizeTags(
      List<Map<String, dynamic>> allTags) {
    Map<String, List<Map<String, dynamic>>> tempCategorizedTags = {};
    for (var tag in allTags) {
      String category = tag['category'] ?? 'Uncategorized';
      if (!tempCategorizedTags.containsKey(category)) {
        tempCategorizedTags[category] = [];
      }
      tempCategorizedTags[category]!.add(tag);
    }
    return tempCategorizedTags;
  }

  Map<String, List<Map<String, dynamic>>> _limitTags(
      Map<String, List<Map<String, dynamic>>> categorizedTags, int limit) {
    Map<String, List<Map<String, dynamic>>> limitedTags = {};
    int count = 0;
    for (var entry in categorizedTags.entries) {
      if (count >= limit) break;
      String category = entry.key;
      List<Map<String, dynamic>> tags = entry.value;
      List<Map<String, dynamic>> limitedTagList = [];

      for (var tag in tags) {
        if (count >= limit) break;
        limitedTagList.add(tag);
        count++;
      }

      if (limitedTagList.isNotEmpty) {
        limitedTags[category] = limitedTagList;
      }
    }
    return limitedTags;
  }

  Widget _buildTagsFilter(Map<String, List<Map<String, dynamic>>> tagsToShow) {
    List<String> selectedTags = List<String>.from(filters['tagNames'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        ...tagsToShow.entries.map((entry) {
          String category = entry.key;
          List<Map<String, dynamic>> tags = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Wrap(
                spacing: 8.0,
                children: tags.map((tag) {
                  String tagName = tag['name'];
                  String icon = tag['icon'] ?? '';
                  bool isSelected = selectedTags.contains(tagName);
                  bool canSelectMore = selectedTags.length < 10 || isSelected;

                  return FilterChip(
                    label: Text('$icon $tagName'),
                    selected: isSelected,
                    onSelected: canSelectMore
                        ? (selected) {
                            setState(() {
                              if (selected) {
                                selectedTags.add(tagName);
                              } else {
                                selectedTags.remove(tagName);
                              }
                              filters['tagNames'] = selectedTags;
                            });
                          }
                        : null,
                  );
                }).toList(),
              ),
              SizedBox(height: 8),
            ],
          );
        }).toList(),
        if (categorizedTags.values.fold(0, (sum, list) => sum + list.length) >
            12)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  showAllTags = !showAllTags;
                });
              },
              child: Text(showAllTags ? 'Show Less' : 'Show All',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    decoration: TextDecoration.underline,
                    decorationColor: Theme.of(context).primaryColor,
                  )),
            ),
          ),
        if (selectedTags.length >= 10)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'You can select up to 10 tags.',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIngredientFilter() {
    List<String> selectedIngredients = filters['ingredientNames'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        ListTile(
          title: Text(selectedIngredients.isEmpty
              ? 'Select Ingredients'
              : '${selectedIngredients.length} ingredients selected'),
          trailing: Icon(Icons.chevron_right),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => IngredientFilterScreen(
                  initialSelectedIngredients: selectedIngredients,
                ),
              ),
            );
            if (result != null) {
              setState(() {
                filters['ingredientNames'] = result;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildCreatedByAIFilter() {
    bool createdByAI = filters['createdByAI'] ?? true; // Turned on by default
    return SwitchListTile(
      title: Text('Show AI-assisted recipes'),
      value: createdByAI,
      onChanged: (value) {
        setState(() {
          filters['createdByAI'] = value;
        });
      },
    );
  }
}
