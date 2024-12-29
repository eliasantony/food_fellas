import 'package:flutter/material.dart';

class SearchFilterModal extends StatefulWidget {
  final Map<String, dynamic> initialFilters;
  final Function(Map<String, dynamic>) onApply;

  SearchFilterModal({required this.initialFilters, required this.onApply});

  @override
  _SearchFilterModalState createState() => _SearchFilterModalState();
}

class _SearchFilterModalState extends State<SearchFilterModal> {
  late Map<String, dynamic> filters;

  @override
  void initState() {
    super.initState();
    filters = Map.from(widget.initialFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Filter Recipes'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onApply(filters);
              Navigator.pop(context);
            },
            child: Text(
              'Apply',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTagFilter(),
            SizedBox(height: 16),
            _buildIngredientFilter(),
            SizedBox(height: 16),
            _buildRatingFilter(),
            SizedBox(height: 16),
            _buildTimeFilter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTagFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: (filters['tagNames'] as List<String>?)?.map((tag) {
                return FilterChip(
                  label: Text(tag),
                  selected: true,
                  onSelected: (selected) {
                    setState(() {
                      if (!selected) {
                        filters['tagNames']!.remove(tag);
                      }
                    });
                  },
                );
              }).toList() ??
              [],
        ),
        TextField(
          decoration: InputDecoration(
            hintText: 'Add a tag',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            setState(() {
              if (filters['tagNames'] == null) {
                filters['tagNames'] = [];
              }
              filters['tagNames'].add(value.trim());
            });
          },
        ),
      ],
    );
  }

  Widget _buildIngredientFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: (filters['ingredientNames'] as List<String>?)?.map((ingredient) {
                return FilterChip(
                  label: Text(ingredient),
                  selected: true,
                  onSelected: (selected) {
                    setState(() {
                      if (!selected) {
                        filters['ingredientNames']!.remove(ingredient);
                      }
                    });
                  },
                );
              }).toList() ??
              [],
        ),
        TextField(
          decoration: InputDecoration(
            hintText: 'Add an ingredient',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            setState(() {
              if (filters['ingredientNames'] == null) {
                filters['ingredientNames'] = [];
              }
              filters['ingredientNames'].add(value.trim());
            });
          },
        ),
      ],
    );
  }

  Widget _buildRatingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Minimum Rating',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Slider(
          value: filters['averageRating']?.toDouble() ?? 0.0,
          min: 0.0,
          max: 5.0,
          divisions: 10,
          label: '${filters['averageRating']?.toDouble() ?? 0.0}',
          onChanged: (value) {
            setState(() {
              filters['averageRating'] = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTimeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maximum Cooking Time',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Slider(
          value: filters['maxCookingTime']?.toDouble() ?? 60.0,
          min: 0.0,
          max: 120.0,
          divisions: 12,
          label: '${filters['maxCookingTime']?.toDouble() ?? 60.0} min',
          onChanged: (value) {
            setState(() {
              filters['maxCookingTime'] = value.toInt();
            });
          },
        ),
      ],
    );
  }
}