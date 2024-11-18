import 'package:flutter/material.dart';

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
  List<Map<String, dynamic>> allTags = []; // To be fetched from Firestore

  @override
  void initState() {
    super.initState();
    filters = Map.from(widget.initialFilters);
    _fetchAvailableTags();
  }

  void _fetchAvailableTags() async {
    // Fetch tags used in this user's recipes from Firestore
    // For now, we'll use dummy data
    // You should replace this with actual data fetching logic
    allTags = [
      {'name': 'Vegetarian', 'emoji': '🥕'},
      {'name': 'Vegan', 'emoji': '🌱'},
      {'name': 'Gluten-Free', 'emoji': '🚫🌾'},
      {'name': 'Dessert', 'emoji': '🍰'},
      {'name': 'Dinner', 'emoji': '🍽️'},
      {'name': 'Spicy', 'emoji': '🌶️'},
      {'name': 'Healthy', 'emoji': '🥗'},
      {'name': 'Quick', 'emoji': '⏱️'},
      {'name': 'Breakfast', 'emoji': '🍳'},
      {'name': 'Lunch', 'emoji': '🥪'},
      {'name': 'Snack', 'emoji': '🍿'},
      {'name': 'Low-Carb', 'emoji': '🍞'},
      {'name': 'High-Protein', 'emoji': '🥩'},
      {'name': 'Low-Calorie', 'emoji': '🥦'},
      {'name': 'Keto', 'emoji': '🥓'},
      {'name': 'Paleo', 'emoji': '🦕'},
      {'name': 'Seafood', 'emoji': '🦐'},
      {'name': 'Chicken', 'emoji': '🍗'},
      {'name': 'Beef', 'emoji': '🥩'},
      {'name': 'Pork', 'emoji': '🥓'},
      {'name': 'Dairy-Free', 'emoji': '🥛'},
      {'name': 'Egg-Free', 'emoji': '🥚'},
      {'name': 'Nut-Free', 'emoji': '🥜'},
      {'name': 'Soy-Free', 'emoji': '🌱'},
      {'name': 'Shellfish-Free', 'emoji': '🦐'},
      {'name': 'Grain-Free', 'emoji': '🌾'},
      {'name': 'Sugar-Free', 'emoji': '🍬'},
      {'name': 'Low-Sodium', 'emoji': '🧂'},
      // Add more tags as needed
    ];

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Build the UI for selecting filters
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
            _buildTagsFilter(),
            _buildCreatedByAIFilter(),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                widget.onApply(filters);
              },
              icon: Icon(
                Icons.filter_alt,
                color: Theme.of(context).canvasColor,
              ),
              label: Text('Apply Filters',
                  style: TextStyle(color: Theme.of(context).canvasColor)),
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.all(Theme.of(context).primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingFilter() {
    double minRating = filters['minRating'] ?? 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Minimum Rating:'),
            Expanded(
              child: Spacer(),
            ),
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
                    filters['minRating'] = value;
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
    int maxCookingTime = filters['maxCookingTime'] ?? 120;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Maximum Cooking Time:'),
            Expanded(child: Spacer()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(maxCookingTime.toString() + ' mins'),
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
                divisions: 20,
                label: maxCookingTime.toStringAsFixed(1),
                onChanged: (value) {
                  setState(() {
                    filters['maxCookingTime'] = value;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTagsFilter() {
    List<String> selectedTags = filters['tags'] ?? [];
    List<Map<String, dynamic>> tagsToShow =
        showAllTags ? allTags : allTags.take(15).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags'),
        Wrap(
          spacing: 8.0,
          children: tagsToShow.map((tag) {
            String tagName = tag['name'];
            String emoji = tag['emoji'] ?? '';
            bool isSelected = selectedTags.contains(tagName);
            return FilterChip(
              label: Text('$emoji $tagName'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedTags.add(tagName);
                  } else {
                    selectedTags.remove(tagName);
                  }
                  filters['tags'] = selectedTags;
                });
              },
            );
          }).toList(),
        ),
        if (allTags.length > 10 && !showAllTags)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  showAllTags = true;
                });
              },
              child: Text('Show All'),
            ),
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
