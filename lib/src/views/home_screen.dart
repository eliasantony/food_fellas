import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:food_fellas/providers/bottomNavBarProvider.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/views/imageToRecipe_screen.dart';
import 'package:food_fellas/src/views/profile_screen.dart';
import 'package:food_fellas/src/widgets/expandableFAB.dart';
import 'package:food_fellas/src/widgets/filterModal.dart';
import 'package:food_fellas/src/widgets/horizontalRecipeRow.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_fellas/src/models/tag.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/src/views/recipeList_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Tag> _mealTypeTags = [];
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isExpandedNotifier = ValueNotifier(true);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _fetchMealTypeTags();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchRows();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  void _handleScroll() {
    final bool isExpanded = _scrollController.offset <= kToolbarHeight;
    if (_isExpandedNotifier.value != isExpanded) {
      _isExpandedNotifier.value = isExpanded;

      // Update status bar color directly, no setState needed
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: isExpanded
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        statusBarIconBrightness:
            isExpanded ? Brightness.light : Brightness.dark,
      ));
    }
  }

  Future<void> _fetchRows() async {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await searchProvider.fetchHomeRowsOnce(userId);
  }

  Future<void> _fetchMealTypeTags() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('tags')
          .where('category', isEqualTo: 'Meal Types')
          .get();

      List<Tag> tags = snapshot.docs.map((doc) {
        return Tag(
          id: doc.id,
          name: doc['name'],
          icon: doc['icon'],
          category: doc['category'],
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _mealTypeTags = tags;
      });
    } catch (e) {
      if (mounted) {
        // Optionally handle the error, e.g., show a message
      }
    }
  }

  Widget _getTimeOfDayIcon() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      // breakfast
      return Icon(Icons.egg_alt_outlined, color: Colors.white, size: 100);
    } else if (hour < 14) {
      // lunch
      return Icon(Icons.lunch_dining, color: Colors.white, size: 100);
    } else if (hour < 18) {
      // snack
      return Icon(Icons.bakery_dining, color: Colors.white, size: 100);
    } else {
      // dinner
      return Icon(Icons.ramen_dining, color: Colors.white, size: 100);
    }
  }

  String _getGreetingMessage(String displayName) {
    DateTime now = DateTime.now();
    int hour = now.hour;

    if (hour < 12) {
      return 'Good Morning, $displayName!';
    } else if (hour < 18) {
      return 'Good Afternoon, $displayName!';
    } else {
      return 'Good Evening, $displayName!';
    }
  }

  String _getMealTimePrompt() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      return 'Looking for breakfast ideas?';
    } else if (hour < 14) {
      return 'What\'s for lunch?';
    } else if (hour < 18) {
      return 'Time for a snack!';
    } else {
      return 'Dinner time! \nWhat\'s on the menu?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    User? currentUser = FirebaseAuth.instance.currentUser;
    bool isLoggedInAndNotGuest =
        currentUser != null && !currentUser.isAnonymous;

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollUpdateNotification) {
          _handleScroll();
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            pinned: true,
            title: ValueListenableBuilder<bool>(
              valueListenable: _isExpandedNotifier,
              builder: (context, isExpanded, child) {
                return isExpanded
                    ? SizedBox.shrink()
                    : _buildCollapsedBar(isLoggedInAndNotGuest);
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _buildExpandedBar(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSearchBar(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildMealTypeCategories(),
          ),
          // Recommended
          if (isLoggedInAndNotGuest)
            SliverToBoxAdapter(child: _buildRecommendedRow()),
          // New Recipes
          SliverToBoxAdapter(
            child: _buildSectionTitle('New Recipes'),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              child: Consumer<SearchProvider>(
                builder: (context, provider, child) {
                  final recipes = provider.rowRecipes['newRecipes'] ?? [];
                  return recipes.isEmpty
                      ? Center(child: CircularProgressIndicator())
                      : HorizontalRecipeRow(recipes: recipes);
                },
              ),
            ),
          ),

          // Top Rated
          SliverToBoxAdapter(
            child: _buildSectionTitle('Top Rated'),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              child: Consumer<SearchProvider>(
                builder: (context, provider, child) {
                  final recipes = provider.rowRecipes['topRated'] ?? [];
                  return recipes.isEmpty
                      ? Center(child: CircularProgressIndicator())
                      : HorizontalRecipeRow(recipes: recipes);
                },
              ),
            ),
          ),

          /* // Most Rated
          SliverToBoxAdapter(
            child: _buildSectionTitle('Most Rated'),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              child: Consumer<SearchProvider>(
                builder: (context, provider, child) {
                  final recipes = provider.rowRecipes['mostRated'] ?? [];
                  return recipes.isEmpty
                      ? Center(child: CircularProgressIndicator())
                      : HorizontalRecipeRow(recipes: recipes);
                },
              ),
            ),
          ),

          // Popular
          SliverToBoxAdapter(
            child: _buildSectionTitle('Popular'),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              child: Consumer<SearchProvider>(
                builder: (context, provider, child) {
                  final recipes = provider.rowRecipes['popular'] ?? [];
                  return recipes.isEmpty
                      ? Center(child: CircularProgressIndicator())
                      : HorizontalRecipeRow(recipes: recipes);
                },
              ),
            ),
          ), */

          // Recently Viewed
          if (isLoggedInAndNotGuest)
            SliverToBoxAdapter(child: _buildRecentlyViewedRow()),
          // Top Chefs
          SliverToBoxAdapter(child: _buildTopChefsRow()),
        ],
      ),
    );
  }

  Widget _buildCollapsedBar(bool isLoggedInAndNotGuest) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Image.asset(
              'lib/assets/brand/hat.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        ShaderMask(
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
            "FoodFellas'",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (isLoggedInAndNotGuest)
          Selector<UserDataProvider, String?>(
            selector: (context, provider) => provider.userData?['photo_url'],
            builder: (context, photoUrl, child) {
              return GestureDetector(
                onTap: () {
                  Provider.of<BottomNavBarProvider>(context, listen: false)
                      .setIndex(4);
                },
                child: CircleAvatar(
                  backgroundColor: Colors.transparent,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : AssetImage('lib/assets/images/DefaultAvatar.png')
                          as ImageProvider,
                ),
              );
            },
          ),
        if (!isLoggedInAndNotGuest)
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: () {
              Provider.of<BottomNavBarProvider>(context, listen: false)
                  .setIndex(4);
            },
          ),
      ],
    );
  }

  Widget _buildExpandedBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Column for greeting + meal-time prompt
            Expanded(
              child: Selector<UserDataProvider, Map<String, dynamic>?>(
                selector: (context, provider) => provider.userData,
                builder: (context, userData, child) {
                  String displayName = userData?['display_name'] ?? 'Guest';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Greet the user first
                      Text(
                        _getGreetingMessage(displayName),
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 8),
                      // Then meal time prompt
                      Text(
                        _getMealTimePrompt(),
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // On the right side, show an icon
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _getTimeOfDayIcon(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final TextEditingController searchController = TextEditingController();
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final bottomNavBarProvider =
        Provider.of<BottomNavBarProvider>(context, listen: false);

    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Search for recipes...',
        prefixIcon: Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: () {
                _openFilterModal(searchProvider);
              },
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed: () {
                final query = searchController.text.trim();
                if (query.isNotEmpty) {
                  searchProvider.updateQuery(query);
                  bottomNavBarProvider.setIndex(1);
                }
              },
            ),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
      ),
    );
  }

  Widget _buildMealTypeCategories() {
    return Container(
      height: 100.0,
      child: _mealTypeTags.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _mealTypeTags.length,
              itemBuilder: (context, index) {
                Tag tag = _mealTypeTags[index];
                return GestureDetector(
                  onTap: () {
                    final searchProvider =
                        Provider.of<SearchProvider>(context, listen: false);
                    searchProvider.updateFilters({
                      'tagNames': [tag.name]
                    });
                    searchProvider.setSortOrder('averageRating:desc');
                    Provider.of<BottomNavBarProvider>(context, listen: false)
                        .setIndex(1);
                  },
                  child: Container(
                    width: 80.0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 28.0,
                          backgroundColor: Colors.orangeAccent,
                          child: Text(
                            tag.icon,
                            style: TextStyle(fontSize: 24.0),
                          ),
                        ),
                        SizedBox(height: 4.0),
                        Flexible(
                          child: Text(
                            tag.name,
                            style: TextStyle(fontSize: 12.0),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// Build the “Recommended” row. Hide if empty or user is new.
  Widget _buildRecommendedRow() {
    final searchProvider = Provider.of<SearchProvider>(context);
    final recipes = searchProvider.recommendedCached;
    if (recipes.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Recommended For You'),
        Container(
          margin: const EdgeInsets.only(left: 8),
          child: HorizontalRecipeRow(recipes: recipes),
        ),
      ],
    );
  }

  /// Build the “Recently Viewed” row
  Widget _buildRecentlyViewedRow() {
    final searchProvider = Provider.of<SearchProvider>(context);
    final recipes = searchProvider.recentlyViewedCached;
    if (recipes.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Recently Viewed'),
        Container(
          margin: const EdgeInsets.only(left: 8.0),
          child: HorizontalRecipeRow(recipes: recipes),
        ),
      ],
    );
  }

  /// Build the “Top Chefs” row
  Widget _buildTopChefsRow() {
    final provider = Provider.of<SearchProvider>(context, listen: true);
    final topChefs = provider.rowUsers['topChefs'] ?? [];
    if (topChefs.isEmpty) return SizedBox.shrink();

    // You can create a custom widget, e.g. HorizontalUserRow
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Text(
            'Top Chefs',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
          ),
        ),
        Container(
          height: 240,
          margin:
              EdgeInsets.fromLTRB(8.0, 0, 0, kBottomNavigationBarHeight + 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: topChefs.length,
            itemBuilder: (context, index) {
              final chef = topChefs[index];
              return _buildChefCard(chef);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChefCard(Map<String, dynamic> chef) {
    final name = chef['display_name'] ?? 'Unknown Chef';
    final photoUrl = chef['photo_url'];
    final avgRating = chef['averageRating']?.toStringAsFixed(1) ?? '0.0';
    final recipeCount = chef['recipeCount'] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => ProfileScreen(userId: chef['id']),
          ),
        );
      },
      child: Container(
        width: 130,
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : AssetImage('lib/assets/images/DefaultAvatar.png')
                      as ImageProvider,
              backgroundColor: Colors.transparent,
            ),
            SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('$recipeCount recipes'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$avgRating'),
                SizedBox(width: 4),
                Icon(Icons.star, color: Colors.orange, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
          ),
          GestureDetector(
            onTap: () {
              final searchProvider =
                  Provider.of<SearchProvider>(context, listen: false);
              final bottomNavBarProvider =
                  Provider.of<BottomNavBarProvider>(context, listen: false);

              // This is the ID of the logged-in user
              String userId = FirebaseAuth.instance.currentUser!.uid;

              // Clear or reset filters if needed
              searchProvider.updateFilters({});

              if (title == 'Recommended For You') {
                // Navigate to a RecipesListScreen that reads the subcollection
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipesListScreen(
                      title: 'Recommended For You',
                      baseQuery: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('recommendations')
                          .orderBy('score', descending: true),
                      isCollection: false,
                    ),
                  ),
                );
              } else if (title == 'Recently Viewed') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipesListScreen(
                      title: 'Recently Viewed',
                      baseQuery: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('interactionHistory')
                          .orderBy('viewedAt', descending: true),
                      isCollection: false,
                    ),
                  ),
                );
              } else if (title == 'New Recipes') {
                // We want to show the “Discover” tab with sort = createdAt desc
                searchProvider.setSortOrder('createdAt:desc');
                bottomNavBarProvider.setIndex(1);
              } else if (title == 'Top Rated') {
                // We want to show the “Discover” tab with sort = avgRating desc
                searchProvider.setSortOrder('averageRating:desc');
                bottomNavBarProvider.setIndex(1);
              } else if (title == 'Most Rated') {
                // We want to show the “Discover” tab with sort = avgRating desc
                searchProvider.setSortOrder('ratingCount:desc');
                bottomNavBarProvider.setIndex(1);
              } else if (title == 'Top Chefs') {
                return;
              }
            },
            child: Text(
              'See All',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFilterModal(SearchProvider searchProvider) {
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
}
