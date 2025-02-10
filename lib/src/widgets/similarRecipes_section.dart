import 'package:flutter/material.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:food_fellas/src/widgets/horizontalRecipeRow.dart';
import 'package:provider/provider.dart';

class SimilarRecipesSection extends StatefulWidget {
  final String recipeId;
  const SimilarRecipesSection({Key? key, required this.recipeId})
      : super(key: key);

  @override
  State<SimilarRecipesSection> createState() => _SimilarRecipesSectionState();
}

class _SimilarRecipesSectionState extends State<SimilarRecipesSection>
    with AutomaticKeepAliveClientMixin {
  String? _lastFetchedId;

  @override
  bool get wantKeepAlive => true; // Ensure the widget is kept alive

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSimilarIfNeeded();
    });
  }

  @override
  void didUpdateWidget(SimilarRecipesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recipeId != oldWidget.recipeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchSimilarIfNeeded();
      });
    }
  }

  void _fetchSimilarIfNeeded() {
    if (_lastFetchedId != widget.recipeId) {
      _lastFetchedId = widget.recipeId;
      context.read<SearchProvider>().fetchSimilarRecipesById(widget.recipeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for AutomaticKeepAliveClientMixin
    final searchProvider = context.watch<SearchProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Similar Recipes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (searchProvider.isLoadingSimilarRecipes)
          const Center(child: CircularProgressIndicator())
        else if (searchProvider.similarRecipes.isNotEmpty)
          HorizontalRecipeRow(
            key: PageStorageKey('similarRecipes-${widget.recipeId}'),
            recipes: searchProvider.similarRecipes,
          )
        else
          const Text('No similar recipes found.'),
      ],
    );
  }
}
