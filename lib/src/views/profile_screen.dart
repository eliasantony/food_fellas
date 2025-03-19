import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/services.dart';
import 'package:food_fellas/providers/bottomNavBarProvider.dart';
import 'package:food_fellas/providers/recipeProvider.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/utils/dialog_utils.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:food_fellas/src/views/collectionDetail_screen.dart';
import 'package:food_fellas/src/views/editProfile_screen.dart';
import 'package:food_fellas/src/views/guestUserScreen.dart';
import 'package:food_fellas/src/views/imageToRecipe_screen.dart';
import 'package:food_fellas/src/views/settings_screen.dart';
import 'package:food_fellas/src/views/shoppingList_screen.dart';
import 'package:food_fellas/src/views/subscriptionScreen.dart';
import 'package:food_fellas/src/views/userFollowerList_screen.dart';
import 'package:food_fellas/src/views/userFollowingList_screen.dart';
import 'package:food_fellas/src/views/userRecipeList_screen.dart';
import 'package:food_fellas/src/widgets/horizontalRecipeRow.dart';
import 'package:food_fellas/src/views/recipeList_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/recipeCard.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final bool showSettings;

  const ProfileScreen({
    Key? key,
    this.userId,
    this.showSettings = false,
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isFollowing = false;
  bool isCurrentUser = false;
  Map<String, dynamic>? userData;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
    _fetchUserData();
  }

  Future<void> _fetchCurrentUserRole() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    if (FirebaseAuth.instance.currentUser!.isAnonymous) return;

    final userProvider =
        Provider.of<UserDataProvider>(this.context, listen: false);
    setState(() {
      _currentUserRole = userProvider.userData?['role'];
    });
  }

  void _fetchUserData() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    String? displayUserId = widget.userId ?? currentUser?.uid;

    if (currentUser == null) {
      return;
    }
    if (currentUser.isAnonymous && displayUserId == null) {
      return;
    }

    // Determine if viewing current user's profile
    isCurrentUser = (displayUserId == currentUser.uid);

    // Fetch user data
    final DocumentReference userDoc =
        FirebaseFirestore.instance.collection('users').doc(displayUserId);

    final DocumentSnapshot userSnapshot = await userDoc.get();
    if (!mounted) return;
    if (userSnapshot.exists) {
      setState(() {
        userData = userSnapshot.data() as Map<String, dynamic>;
      });

      if (!isCurrentUser) {
        // Check if the current user is following this user
        final followerDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(displayUserId)
            .collection('followers')
            .doc(currentUser.uid);

        final followerSnapshot = await followerDoc.get();
        setState(() {
          isFollowing = followerSnapshot.exists;
        });
      }
    }
  }

  void _toggleFollow() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || userData == null) return;

    String profileUserId = userData!['uid'];

    final followerDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(profileUserId)
        .collection('followers')
        .doc(currentUser.uid);

    final followingDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(profileUserId);

    if (isFollowing) {
      // Unfollow
      await followerDoc.delete();
      await followingDoc.delete();
    } else {
      // Follow
      await followerDoc.set({
        'uid': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await followingDoc.set({
        'uid': profileUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    setState(() {
      isFollowing = !isFollowing;
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Show snackbar message
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(isFollowing ? 'Followed user' : 'Unfollowed user'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    bool isGuestUser = currentUser == null || currentUser.isAnonymous;

    // If the current user is a guest and is viewing their own profile,
    // show a limited guest view.
    if (isGuestUser &&
        (widget.userId == null || widget.userId == currentUser?.uid)) {
      return GuestUserScreen(
          title: "Profile", message: "Sign up to view the full profile");
    }

    // Otherwise, proceed to load user data.
    if (userData == null) {
      // Show loading indicator
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _buildProfileScreen(context, theme, userData!);
  }

  Widget _buildProfileScreen(
      BuildContext context, ThemeData theme, Map<String, dynamic> userData) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    bool isGuestUser = currentUser == null || currentUser.isAnonymous;

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
            "Profile",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: isCurrentUser
            ? [
                IconButton(
                  icon: Icon(Icons.shopping_cart_outlined,
                      color: theme.iconTheme.color),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ShoppingListScreen(),
                      ),
                    );
                  },
                ),
                PopupMenuButton<int>(
                  icon: Icon(Icons.more_vert, color: theme.iconTheme.color),
                  onSelected: (item) async {
                    switch (item) {
                      case 0:
                        // Navigate to edit profile screen
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditProfileScreen(userData: userData!),
                          ),
                        );
                        // Refresh the profile data after returning
                        _fetchUserData();
                        break;
                      case 1:
                        // Navigate to settings screen
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SettingsScreen(userData: userData),
                          ),
                        );
                        // Refresh the profile data if necessary
                        _fetchUserData();
                        break;
                      case 2:
                        // Share profile
                        final currentUserId =
                            FirebaseAuth.instance.currentUser!.uid;
                        final String profileUrl =
                            'https://foodfellas.app/share/profile/$currentUserId';
                        Share.share(
                            "Check out my profile on FoodFellas':\n$profileUrl");
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<int>(
                      value: 0,
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: theme.iconTheme.color),
                          SizedBox(width: 8),
                          Text('Edit Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem<int>(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(Icons.settings, color: theme.iconTheme.color),
                          SizedBox(width: 8),
                          Text('Settings'),
                        ],
                      ),
                    ),
                    PopupMenuItem<int>(
                      value: 2,
                      child: Row(
                        children: [
                          Icon(Icons.share, color: theme.iconTheme.color),
                          SizedBox(width: 8),
                          Text('Share Profile'),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.share, color: theme.iconTheme.color),
                  onPressed: () {
                    final userId = userData['uid'] ?? 'user';
                    final userName = userData['display_name'] ?? 'User';
                    final String profileUrl =
                        'https://foodfellas.app/share/profile/$userId';
                    Share.share(
                        "Check out this profile from $userName on FoodFellas':\n$profileUrl");
                  },
                ),
              ],
        leading: GestureDetector(
          onTap: () {
            if (Navigator.canPop(context)) {
              // If there's a previous screen in the stack, pop back
              Navigator.pop(context);
            } else {
              // Otherwise, switch to home tab
              Provider.of<BottomNavBarProvider>(context, listen: false)
                  .setIndex(0);
            }
          },
          child: Padding(
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
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            // Profile Header
            _buildProfileHeader(theme, userData, isGuestUser),
            // Average Rating Section
            _buildAverageRatingSection(theme, userData['uid']),
            // Statistics Section
            _buildStatisticsSection(context, theme, userData),
            // Recipes Section
            _buildRecipesSection(context, theme, userData),
            // Collections Section
            _buildCollectionsSection(context, theme, userData, isCurrentUser),
            // Contributed Collections Section
            _buildContributedCollectionsSection(
                context, theme, userData, isCurrentUser),
            // Followed Collections Section
            _buildFollowedCollectionsSection(context),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      ThemeData theme, Map<String, dynamic> userData, bool isGuestUser) {
    String displayName = userData['display_name'] ?? 'No Name';
    String photoUrl = userData['photo_url'] ??
        'https://via.placeholder.com/150'; // Default image if none provided
    String shortDescription = userData['shortDescription'] ?? '';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(photoUrl),
            radius: 60, // Reduced radius
            backgroundColor: Colors.transparent,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.headlineSmall,
                    ),
                    SizedBox(width: 8),
                    if (userData['role'] == 'admin')
                      Icon(Icons.security_rounded, color: Colors.blue),
                    SizedBox(width: 4),
                    if (userData['subscribed'] == true)
                      Icon(Icons.stars_rounded, color: Colors.amber),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  shortDescription,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.left,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!isCurrentUser && !isGuestUser)
            Tooltip(
              message: isFollowing
                  ? 'Unfollow ${userData['display_name']}'
                  : 'Follow ${userData['display_name']}',
              child: IconButton(
                iconSize: 24,
                icon: isFollowing
                    ? Icon(Icons.person_add_disabled_rounded)
                    : Icon(Icons.person_add_rounded),
                color: isFollowing ? Colors.red[600] : Colors.green[600],
                onPressed: _toggleFollow,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAverageRatingSection(ThemeData theme, String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(); // Loading
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;

        double averageRating = userData['averageRating']?.toDouble() ?? 0.0;
        int totalReviews = userData['totalReviews'] ?? 0;

        if (totalReviews == 0) {
          return SizedBox(); // No reviews, so no average rating
        }

        return Column(
          children: [
            Text(
              'Average Recipe Ratings:',
              style: theme.textTheme.bodyMedium,
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  averageRating.toStringAsFixed(1),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.star, color: Colors.amber),
              ],
            ),
            SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildStatisticsSection(
      BuildContext context, ThemeData theme, Map<String, dynamic> userData) {
    String userId = userData['uid'] ?? FirebaseAuth.instance.currentUser!.uid;

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('recipes')
          .where('authorId', isEqualTo: userId)
          .get(),
      builder: (context, snapshot) {
        int recipeCount = 0;
        if (snapshot.hasData && snapshot.data != null) {
          recipeCount = snapshot.data!.docs.length;
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('followers')
              .get(),
          builder: (context, followerSnapshot) {
            int followersCount = 0;
            if (followerSnapshot.hasData && followerSnapshot.data != null) {
              followersCount = followerSnapshot.data!.docs.length;
            }

            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('following')
                  .get(),
              builder: (context, followingSnapshot) {
                int followingCount = 0;
                if (followingSnapshot.hasData &&
                    followingSnapshot.data != null) {
                  followingCount = followingSnapshot.data!.docs.length;
                }

                final String titleForRecipes;
                if (isCurrentUser) {
                  titleForRecipes = 'My Recipes';
                } else {
                  titleForRecipes = '${userData['display_name']}\'s Recipes';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      _ProfileStatistic(
                        title: 'Recipes',
                        value: '$recipeCount',
                        onTap: () {
                          final recipesQuery = FirebaseFirestore.instance
                              .collection('recipes')
                              .where('authorId', isEqualTo: userId);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipesListScreen(
                                baseQuery: recipesQuery,
                                title: titleForRecipes,
                              ),
                            ),
                          );
                        },
                      ),
                      _ProfileStatistic(
                        title: 'Followers',
                        value: '$followersCount',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FollowersListScreen(
                                  userId: userId,
                                  displayName: userData['display_name']),
                            ),
                          );
                        },
                      ),
                      _ProfileStatistic(
                        title: 'Following',
                        value: '$followingCount',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FollowingListScreen(
                                  userId: userId,
                                  displayName: userData['display_name']),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCollectionsSection(BuildContext context, ThemeData theme,
      Map<String, dynamic> userData, bool isCurrentUser) {
    String userId = userData['uid'];

    // Define the collection stream with appropriate filters
    Stream<QuerySnapshot> collectionStream;
    if (isCurrentUser || _currentUserRole == 'admin') {
      // Current user can access all their collections
      collectionStream = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('collections')
          .snapshots();
    } else {
      // For other users, only fetch public collections
      collectionStream = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('collections')
          .where('isPublic', isEqualTo: true)
          .snapshots();
    }

    return Column(
      children: [
        SizedBox(height: 20),
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            isCurrentUser
                ? 'My Collections'
                : '${userData['display_name']}\'s Collections',
            style: theme.textTheme.titleLarge,
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: 200,
          child: StreamBuilder<QuerySnapshot>(
            stream: collectionStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error fetching collections'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                // No collections yet
                if (isCurrentUser) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCreateCollectionCard(context, theme),
                      ],
                    ),
                  );
                } else {
                  return Center(
                      child: Text('This user has no public collections.'));
                }
              }
              final collections = snapshot.data!.docs;

              return Container(
                margin: const EdgeInsets.only(left: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: isCurrentUser
                      ? collections.length + 1
                      : collections.length,
                  itemBuilder: (context, index) {
                    if (isCurrentUser) {
                      if (index == 0) {
                        // Always show "Create New" card as the first item
                        return _buildCreateCollectionCard(context, theme);
                      } else {
                        final collection = collections[index - 1];
                        final collectionData =
                            collection.data() as Map<String, dynamic>;
                        return _buildCollectionCard(context, theme, userId,
                            collection.id, collectionData);
                      }
                    } else {
                      final collection = collections[index];
                      final collectionData =
                          collection.data() as Map<String, dynamic>;
                      return _buildCollectionCard(context, theme, userId,
                          collection.id, collectionData);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFollowedCollectionsSection(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (!isCurrentUser || currentUser == null) {
      return SizedBox(); // Only show this if it's the current user's profile
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Followed Collections',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SizedBox(height: 10),
        Container(
          margin:
              const EdgeInsets.only(bottom: kBottomNavigationBarHeight + 32),
          height: 200,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .collection('followedCollections')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error loading followed collections'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No followed collections.'));
              }
              final followedDocs = snapshot.data!.docs;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: followedDocs.length,
                itemBuilder: (context, index) {
                  final data =
                      followedDocs[index].data() as Map<String, dynamic>;
                  final ownerUid = data['collectionOwnerUid'];
                  final colId = data['collectionId'];
                  // fetch the actual collection doc
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(ownerUid)
                        .collection('collections')
                        .doc(colId)
                        .get(),
                    builder: (context, colSnapshot) {
                      if (!colSnapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (!colSnapshot.data!.exists) {
                        return SizedBox(
                          width: 120,
                          child: Center(child: Text('Not found')),
                        );
                      }
                      final colData =
                          colSnapshot.data!.data() as Map<String, dynamic>;
                      return _buildCollectionCard(
                        context,
                        Theme.of(context),
                        ownerUid,
                        colId,
                        colData,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // profile_screen.dart

  Widget _buildContributedCollectionsSection(BuildContext context,
      ThemeData theme, Map<String, dynamic> userData, bool isCurrentUser) {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final userId = userData['uid'];

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: recipeProvider.getContributedCollections(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Center(child: Text('Error fetching contributed collections'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox(); // No contributed collections to show
        } else {
          final contributedCollections = snapshot.data!;

          return Column(
            children: [
              SizedBox(height: 20),
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Contributed Collections',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              SizedBox(height: 10),
              Container(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: contributedCollections.length,
                  itemBuilder: (context, index) {
                    final collection = contributedCollections[index];
                    return _buildContributedCollectionCard(
                        context, theme, collection);
                  },
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildContributedCollectionCard(BuildContext context, ThemeData theme,
      Map<String, dynamic> collectionData) {
    String name = collectionData['name'] ?? 'Unnamed';
    String icon = collectionData['icon'] ?? '🍽';
    List<dynamic> recipes = collectionData['recipes'] ?? [];
    bool isPublic = collectionData['isPublic'] ?? false;
    int followersCount = collectionData['followersCount'] ?? 0;
    double averageRating = (collectionData['averageRating'] ?? 0.0).toDouble();
    int ratingsCount = collectionData['ratingsCount'] ?? 0;
    List<String> contributors =
        collectionData['contributors']?.cast<String>() ?? [];

    String ownerUid = collectionData['ownerUid'] ?? '';

    return GestureDetector(
      onTap: () {
        // Navigate to the collection's detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipesListScreen(
              isCollection: true,
              collectionUserId: ownerUid,
              collectionId: collectionData['id'],
              collectionName: name,
              collectionEmoji: icon,
              collectionVisibility: isPublic,
              collectionContributors: contributors,
            ),
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Container(
          width: 120,
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: TextStyle(fontSize: 40)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isPublic)
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text('${recipes.length} recipes',
                  style: theme.textTheme.titleSmall),
              // Show followers
              if (isPublic) ...[
                SizedBox(height: 8),
                Text('$followersCount followers',
                    style: theme.textTheme.bodySmall),
              ],
              // Show average rating
              if (ratingsCount > 0) ...[
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${averageRating.toStringAsFixed(1)} ($ratingsCount)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

// Collection Card
  Widget _buildCollectionCard(
    BuildContext context,
    ThemeData theme,
    String userId, // The collection's owner
    String collectionId,
    Map<String, dynamic> collectionData,
  ) {
    String name = collectionData['name'] ?? 'Unnamed';
    String icon = collectionData['icon'] ?? '🍽';
    List<dynamic> recipes = collectionData['recipes'] ?? [];
    bool isPublic = collectionData['isPublic'] ?? false;
    int followersCount = collectionData['followersCount'] ?? 0;
    double averageRating = (collectionData['averageRating'] ?? 0.0).toDouble();
    int ratingsCount = collectionData['ratingsCount'] ?? 0;
    List<String> contributors =
        collectionData['contributors']?.cast<String>() ?? [];

    return GestureDetector(
      onTap: () {
        // Navigate to that collection
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipesListScreen(
              isCollection: true,
              collectionUserId: userId,
              collectionId: collectionId,
              collectionName: name,
              collectionEmoji: icon,
              collectionVisibility: isPublic,
              collectionContributors: contributors,
            ),
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Container(
          width: 120,
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: TextStyle(fontSize: 40)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isPublic)
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text('${recipes.length} recipes',
                  style: theme.textTheme.titleSmall),
              // NEW: show followers
              if (isPublic) ...[
                SizedBox(height: 8),
                Text('$followersCount followers',
                    style: theme.textTheme.bodySmall),
              ],
              // NEW: show average rating
              if (ratingsCount > 0) ...[
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${averageRating.toStringAsFixed(1)} ($ratingsCount)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleCreateCollectionTap(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Query the user's current collection count.
    final collectionsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('collections')
        .get();
    final collectionsCount = collectionsSnapshot.docs.length;

    // Get subscription status from your provider.
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    final isSubscribed = userProvider.userData?['subscribed'] ?? false;

    // Free users can create only up to 2 collections.
    if (!isSubscribed && collectionsCount >= 2) {
      // Show a subscription prompt dialog.
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Upgrade to Premium? ✨"),
          content: Text(
            "You have reached your limit of 2 collections. Upgrade to Premium for unlimited collections and other benefits!",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Not Now"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to your subscription screen or initiate purchase flow.
                // For example:
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SubscriptionScreen()));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary),
              child: Text("Upgrade"),
            ),
          ],
        ),
      );
    } else {
      // Allow user to create a new collection.
      showCreateCollectionDialog(context);
    }
  }

// Create New Collection Card
  Widget _buildCreateCollectionCard(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: () => _handleCreateCollectionTap(context),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Container(
          width: 120,
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 40),
              SizedBox(height: 8),
              Text(
                'Create New Collection',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Create New Collection Card
  Widget _buildCreateRecipeCard(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        _showCreateRecipeOptions(context);
      },
      child: Card(
        child: Container(
          width: 120,
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 40),
              SizedBox(height: 8),
              Text(
                'Create New Recipe',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateRecipeOptions(context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.create),
                title: Text('Create a recipe from scratch'),
                onTap: () {
                  Navigator.pop(context); // Close the bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddRecipeForm()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Image to Recipe'),
                onTap: () {
                  Navigator.pop(context); // Close the bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ImageToRecipeScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.chat),
                title: Text('Chat with AI'),
                onTap: () {
                  Navigator.pop(context); // Close the bottom sheet
                  Provider.of<BottomNavBarProvider>(context, listen: false)
                      .setIndex(3);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Create show all recipes Card
  Widget _buildShowAllRecipesCard(BuildContext context, ThemeData theme) {
    final String titleForRecipes;
    if (isCurrentUser) {
      titleForRecipes = 'My Recipes';
    } else {
      titleForRecipes = '${userData?['display_name']}\'s Recipes';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipesListScreen(
              baseQuery: FirebaseFirestore.instance.collection('recipes').where(
                  'authorId',
                  isEqualTo: isCurrentUser
                      ? FirebaseAuth.instance.currentUser!.uid
                      : widget.userId),
              title: titleForRecipes,
              isCollection: false,
            ),
          ),
        );
      },
      child: Card(
        child: Container(
          width: 120,
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.more_horiz, size: 40),
              SizedBox(height: 8),
              Text(
                'Show All Recipes',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ProfileStatistic({
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipesSection(
      BuildContext context, ThemeData theme, Map<String, dynamic> userData) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Section Header
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Left Padding
          child: Text(
            isCurrentUser
                ? 'My Recipes'
                : '${userData['display_name']}\'s Recipes',
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 10),
        // Recipes Row
        Padding(
          padding: const EdgeInsets.only(left: 8.0), // Match left padding
          child: _buildUserRecipesRow(context, theme, userData),
        ),
      ],
    );
  }

  Widget _buildUserRecipesRow(
      BuildContext context, ThemeData theme, Map<String, dynamic> userData) {
    String userId = userData['uid'] ?? FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching recipes'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final recipes = snapshot.data!.docs;

        // Add the "Create New Recipe" card explicitly
        List<Widget> recipeWidgets = [
          if (isCurrentUser) _buildCreateRecipeCard(context, theme),
        ];

        // Show the latest 5 recipes and add the "Show All Recipes" card if needed
        if (recipes.isNotEmpty) {
          recipeWidgets.addAll(
            recipes.take(5).map((doc) {
              return RecipeCard(
                recipeId: doc.id,
              );
            }),
          );

          if (recipes.length > 5) {
            recipeWidgets.add(
              _buildShowAllRecipesCard(context, theme),
            );
          }
        } else if (!isCurrentUser) {
          return SizedBox(
            height: 170,
            child: Center(
                child: Text('This user has not created any recipes yet.')),
          );
        }

        return SizedBox(
          height: 290,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: recipeWidgets,
          ),
        );
      },
    );
  }
}
