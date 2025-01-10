import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:food_fellas/providers/recipeProvider.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:food_fellas/src/views/profile_screen.dart';
import 'package:food_fellas/src/widgets/filterModal.dart';
import 'package:food_fellas/src/widgets/recipeCard.dart';
import 'package:food_fellas/src/widgets/searchFilterModal.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/categoryCard.dart';
import '../widgets/verticalRecipeColumn.dart';
import 'package:provider/provider.dart';

class DiscoverScreen extends StatefulWidget {
  @override
  _DiscoverScreenState createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentOffset = 0;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _fetchInitialRecipes();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMoreRecipes();
      }
    });
  }

  Future<void> _fetchInitialRecipes() async {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    _currentOffset = 0;
    await searchProvider.fetchRecipes(offset: _currentOffset, limit: _limit);
  }

  Future<void> _loadMoreRecipes() async {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    _currentOffset += _limit;
    await searchProvider.fetchRecipes(offset: _currentOffset, limit: _limit);
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context);

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
            "Discover",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: _getTooltipForMode(searchProvider.searchMode),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: searchProvider.searchMode != SearchMode.users
                          ? IconButton(
                              icon: Icon(Icons.filter_list),
                              onPressed: () => _openFilterModal(context),
                            )
                          : null,
                    ),
                    onChanged: (query) {
                      // Depending on the toggle, call appropriate method
                      if (searchProvider.searchMode == SearchMode.users) {
                        searchProvider.fetchUsers(query);
                      } else if (searchProvider.searchMode ==
                          SearchMode.recipes) {
                        searchProvider.updateQuery(query);
                      } else if (searchProvider.searchMode == SearchMode.both) {
                        searchProvider.fetchMultiSearch(query);
                      }
                    },
                  ),
                ),
                // Search Toggle
                _buildSearchToggle(context),
              ],
            ),
          ),
          // Active Filters Bar
          _buildActiveFilters(context, searchProvider.filters),
          // Search Results
          Expanded(
            child: _buildResults(searchProvider),
          ),
        ],
      ),
    );
  }

  String _getTooltipForMode(SearchMode mode) {
    switch (mode) {
      case SearchMode.users:
        return "Search Users";
      case SearchMode.recipes:
        return "Search Recipes";
      case SearchMode.both:
        return "Search Recipes & Users";
      default:
        return "Unknown Mode";
    }
  }

  Widget _buildSearchToggle(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context);

    IconData _getIconForMode(SearchMode mode) {
      switch (mode) {
        case SearchMode.users:
          return Icons.person;
        case SearchMode.recipes:
          return Icons.restaurant_menu;
        case SearchMode.both:
          return Icons.search;
        default:
          return Icons.help;
      }
    }

    void _toggleSearchMode() {
      switch (searchProvider.searchMode) {
        case SearchMode.users:
          searchProvider.setSearchMode(SearchMode.recipes);
          break;
        case SearchMode.recipes:
          searchProvider.setSearchMode(SearchMode.both);
          break;
        case SearchMode.both:
          searchProvider.setSearchMode(SearchMode.users);
          break;
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: IconButton(
        icon: Icon(_getIconForMode(searchProvider.searchMode)),
        tooltip: _getTooltipForMode(searchProvider.searchMode),
        onPressed: _toggleSearchMode,
      ),
    );
  }

  Widget _buildResults(SearchProvider searchProvider) {
    if (searchProvider.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // If "Users" only
    if (searchProvider.searchMode == SearchMode.users) {
      if (searchProvider.users.isEmpty) {
        return Center(child: Text("No users found."));
      }
      return ListView.builder(
        itemCount: searchProvider.users.length,
        itemBuilder: (context, index) {
          final userDoc = searchProvider.users[index];
          return _buildUserTile(context, userDoc);
        },
      );
    }

    // If "Recipes" only (old behavior)
    if (searchProvider.searchMode == SearchMode.recipes) {
      if (searchProvider.recipes.isEmpty) {
        return Center(child: Text("No recipes found."));
      }
      return ListView.builder(
        controller: _scrollController,
        itemCount: searchProvider.recipes.length,
        itemBuilder: (context, index) {
          final recipe = searchProvider.recipes[index];
          return RecipeCard(recipeId: recipe['id']);
        },
      );
    }

    // If "Both": show user(s) first if any, then recipes
    if (searchProvider.searchMode == SearchMode.both) {
      // If both sets are empty
      if (searchProvider.users.isEmpty && searchProvider.recipes.isEmpty) {
        return Center(child: Text("No results found."));
      }
      return ListView(
        children: [
          // 1) Possibly show a user section if _users is not empty
          if (searchProvider.users.isNotEmpty)
            ...searchProvider.users.map((userDoc) {
              return _buildUserTile(context, userDoc);
            }).toList(),

          // 2) Then show the recipes
          if (searchProvider.recipes.isNotEmpty)
            ...searchProvider.recipes.map((recipe) {
              return RecipeCard(recipeId: recipe['id']);
            }).toList(),
        ],
      );
    }

    // Fallback
    return Container();
  }

  Widget _buildUserTile(BuildContext context, Map<String, dynamic> userData) {
    // This is how you might replicate your userFollowerList_screen style.
    // For example, tapping navigates to that user’s ProfileScreen.
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: userData['id']),
          ),
        );
      },
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage(userData['photo_url'] ?? ''),
        backgroundColor: Colors.transparent,
      ),
      title: Text(userData['display_name'] ?? 'Unknown'),
      subtitle: Text(
        userData['shortDescription'] ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // In discover_screen.dart, replace _openFilterModal if needed:
  void _openFilterModal(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: FilterModal(
            initialFilters: searchProvider.filters,
            onApply: (filters) {
              searchProvider.updateFilters(filters);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  Widget _buildActiveFilters(
      BuildContext context, Map<String, dynamic> filters) {
    List<Widget> filterChips = [];

    // tagNames
    if (filters.containsKey('tagNames') && filters['tagNames'].isNotEmpty) {
      List<String> selectedTags = filters['tagNames'];
      for (String tag in selectedTags) {
        filterChips.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Chip(
              label: Text(tag),
              onDeleted: () => _removeFilter(context, 'tagNames', tag),
              deleteIconColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Theme.of(context).primaryColor,
                ),
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        );
      }
    }

    // averageRating
    if (filters.containsKey('averageRating') && filters['averageRating'] > 0) {
      double rating = filters['averageRating'];
      filterChips.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Chip(
            label: Text('Rating ≥ ${rating.toStringAsFixed(1)} ⭐'),
            onDeleted: () => _removeFilter(context, 'averageRating', null),
            deleteIconColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Theme.of(context).primaryColor,
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      );
    }

    // cookingTimeInMinutes
    if (filters.containsKey('cookingTimeInMinutes')) {
      int time = filters['cookingTimeInMinutes'].toInt();
      filterChips.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Chip(
            label: Text('Time ≤ $time mins ⏱️'),
            onDeleted: () =>
                _removeFilter(context, 'cookingTimeInMinutes', null),
            deleteIconColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Theme.of(context).primaryColor,
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      );
    }

    // ingredientNames
    if (filters.containsKey('ingredientNames') &&
        filters['ingredientNames'].isNotEmpty) {
      List<String> selectedIngredients = filters['ingredientNames'];
      for (String ingredient in selectedIngredients) {
        filterChips.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Chip(
              label: Text(ingredient),
              onDeleted: () =>
                  _removeFilter(context, 'ingredientNames', ingredient),
              deleteIconColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Theme.of(context).primaryColor,
                ),
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        );
      }
    }

    // createdByAI
    if (filters.containsKey('createdByAI') && filters['createdByAI'] == true) {
      filterChips.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Chip(
            label: Text('🤖 AI-assisted'),
            onDeleted: () => _removeFilter(context, 'createdByAI', null),
            deleteIconColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).primaryColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      );
    }

    if (filterChips.isEmpty) {
      return SizedBox.shrink(); // If no active filters, no bar
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filterChips,
      ),
    );
  }

  void _removeFilter(BuildContext context, String key, dynamic value) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    Map<String, dynamic> currentFilters = Map.from(searchProvider.filters);

    if (key == 'tagNames' || key == 'ingredientNames') {
      // For array filters, remove the specific value
      List<dynamic> list = List.from(currentFilters[key] ?? []);
      list.remove(value);
      if (list.isEmpty) {
        currentFilters.remove(key);
      } else {
        currentFilters[key] = list;
      }
    } else {
      // For single-value filters, just remove the key
      currentFilters.remove(key);
    }

    searchProvider.updateFilters(currentFilters);
  }
}
