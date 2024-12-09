import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:food_fellas/main.dart';
import 'package:food_fellas/providers/bottomNavBarProvider.dart';
import 'package:food_fellas/src/views/aichat_screen.dart';
import 'package:food_fellas/src/views/imageToRecipe_screen.dart';
import 'package:food_fellas/src/widgets/expandableFAB.dart';
import 'package:food_fellas/src/widgets/mockupHorizontalRecipeRow.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_fellas/src/models/tag.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? _currentUser;
  String _displayName = '';
  String? _photoUrl;
  List<Tag> _mealTypeTags = [];

  @override
  void initState() {
    super.initState();
    _fetchCurrentUser();
    _fetchMealTypeTags();
  }

  Future<void> _fetchCurrentUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String uid = user.uid;
      final DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentUser = user;
          _displayName = userData['display_name'] ?? 'Guest';
          _photoUrl = userData['photo_url'];
        });
      } else {
        setState(() {
          _currentUser = user;
          _displayName = 'Guest';
          _photoUrl = null;
        });
      }
    } else {
      setState(() {
        _currentUser = null;
        _displayName = 'Guest';
        _photoUrl = null;
      });
    }
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

      if (!mounted) return; // Ensure the widget is still mounted

      setState(() {
        _mealTypeTags = tags;
      });
    } catch (e) {
      if (mounted) {
        // Optionally handle the error, e.g., show a message
      }
    }
  }

  String _getGreetingMessage() {
    DateTime now = DateTime.now();
    int hour = now.hour;

    if (hour < 12) {
      return 'Good Morning, $_displayName!';
    } else if (hour < 18) {
      return 'Good Afternoon, $_displayName!';
    } else {
      return 'Good Evening, $_displayName!';
    }
  }

  String _getTitle() {
    DateTime now = DateTime.now();
    int hour = now.hour;

    if (hour < 11) {
      return 'Looking for breakfast ideas?';
    } else if (hour < 14) {
      return 'What\'s for lunch today?';
    } else if (hour < 18) {
      return 'Time for a snack!';
    } else {
      return 'Dinner time! What\'s on the menu?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: ExpandableFab(
        distance: 130,
        children: [
          ActionButton(
            onPressed: () {
              Provider.of<BottomNavBarProvider>(context, listen: false)
                  .setIndex(3);
            },
            icon: const Icon(Icons.chat),
          ),
          ActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddRecipeForm()),
              );
            },
            icon: const Icon(Icons.create),
          ),
          ActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ImageToRecipeScreen()),
              );
            },
            icon: const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 180.0,
          pinned: true,
          flexibleSpace: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              var top = constraints.biggest.height;
              bool isExpanded = top > kToolbarHeight + 50;

              return FlexibleSpaceBar(
                titlePadding:
                    EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                centerTitle: false,
                title: isExpanded
                    ? null
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SvgPicture.asset(
                            'lib/assets/brand/FoodFellas_Heading.svg',
                            height: 30.0,
                          ),
                          GestureDetector(
                            onTap: () {
                              Provider.of<BottomNavBarProvider>(context,
                                      listen: false)
                                  .setIndex(4);
                            },
                            child: CircleAvatar(
                              backgroundColor: Colors.transparent,
                              backgroundImage: _photoUrl != null
                                  ? NetworkImage(_photoUrl!)
                                  : const AssetImage(
                                          'lib/assets/images/DefaultAvatar.png')
                                      as ImageProvider,
                            ),
                          ),
                        ],
                      ),
                background: isExpanded
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.inversePrimary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(16.0),
                            bottomRight: Radius.circular(16.0),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Column for greeting and title text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 20.0),
                                    Text(
                                      _getTitle(),
                                      style: TextStyle(
                                        fontSize: 22.0,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      _getGreetingMessage(),
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Adding the 3D AI sparkles illustration on the right
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Image.asset(
                                  'lib/assets/images/SPARKLES_EMOJI.png',
                                  height: 100,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : null,
              );
            },
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
        SliverToBoxAdapter(
          child: _buildSectionTitle('Recommended'),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            child: MockupHorizontalRecipeRow(),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildSectionTitle('New Recipes'),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            child: MockupHorizontalRecipeRow(),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildSectionTitle('Top Rated'),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            child: MockupHorizontalRecipeRow(),
          ),
        ),
        // Add more sections as needed
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search for recipes...',
        prefixIcon: Icon(Icons.search),
        suffixIcon: IconButton(
          icon: Icon(Icons.filter_list),
          onPressed: () {
            // Implement filter functionality
          },
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
      height: 100.0, // Increased height to prevent overflow
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: _mealTypeTags.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _mealTypeTags.length,
              itemBuilder: (context, index) {
                Tag tag = _mealTypeTags[index];
                return GestureDetector(
                  onTap: () {
                    // Implement category selection
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
              // Implement navigation to the full list of items
            },
            child: Text(
              'See All',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
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
}
