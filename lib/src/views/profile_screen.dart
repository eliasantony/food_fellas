import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/services.dart';
import 'package:food_fellas/src/utils/dialog_utils.dart';
import 'package:food_fellas/src/views/collectionDetail_screen.dart';
import 'package:food_fellas/src/views/userFollowerList_screen.dart';
import 'package:food_fellas/src/views/userFollowingList_screen.dart';
import 'package:food_fellas/src/views/userRecipeList_screen.dart';
import 'package:food_fellas/src/widgets/horizontalRecipeRow.dart';
import 'package:food_fellas/src/widgets/recipeList_screen.dart';
import 'package:path/path.dart';
import '../widgets/recipeCard.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  ProfileScreen({this.userId});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isFollowing = false;
  bool isCurrentUser = false;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    String? displayUserId = widget.userId ?? currentUser?.uid;

    if (currentUser == null) {
      // Handle unauthenticated user
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${userData['display_name']}',
            style: theme.textTheme.titleLarge),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: isCurrentUser
            ? [
                IconButton(
                  icon: Icon(Icons.edit, color: theme.iconTheme.color),
                  onPressed: () {
                    // Navigate to edit profile screen
                  },
                ),
                IconButton(
                  icon: Icon(Icons.settings, color: theme.iconTheme.color),
                  onPressed: () {
                    // Navigate to settings screen or perform other actions
                  },
                ),
              ]
            : [],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            // Profile Header
            _buildProfileHeader(theme, userData),
            // Average Rating Section
            _buildAverageRatingSection(theme, userData['uid']),
            // Statistics Section
            _buildStatisticsSection(context, theme, userData),
            // Recipes Section
            _buildRecipesSection(context, theme, userData),
            // Collections Section
            _buildCollectionsSection(context, theme, userData, isCurrentUser),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, Map<String, dynamic> userData) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: theme.textTheme.headlineSmall,
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
          if (!isCurrentUser) Spacer(),
          if (!isCurrentUser)
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
        int recipesCount = 0;
        if (snapshot.hasData && snapshot.data != null) {
          recipesCount = snapshot.data!.docs.length;
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
                  .doc(FirebaseAuth.instance.currentUser!.uid)
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
                        value: '$recipesCount',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipesListScreen(
                                baseQuery: FirebaseFirestore.instance
                                    .collection('recipes')
                                    .where('authorId',
                                        isEqualTo: widget.userId),
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
    if (isCurrentUser) {
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
          height: 170,
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
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCreateCollectionCard(context, theme),
                    ],
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
                      ? collections.length + 1 // Extra item for "Create New"
                      : collections.length,
                  itemBuilder: (context, index) {
                    if (isCurrentUser && index == collections.length) {
                      // "Create New" card
                      return _buildCreateCollectionCard(context, theme);
                    } else {
                      final collection = collections[index];
                      final collectionData =
                          collection.data() as Map<String, dynamic>;
                      return _buildCollectionCard(
                          context, theme, collection.id, collectionData);
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

// Collection Card
  Widget _buildCollectionCard(BuildContext context, ThemeData theme,
      String collectionId, Map<String, dynamic> collectionData) {
    String name = collectionData['name'] ?? 'Unnamed';
    String icon = collectionData['icon'] ?? '🍽';
    List<dynamic> recipes = collectionData['recipes'] ?? [];

    return GestureDetector(
      onTap: () {
        // Navigate to Collection Detail Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CollectionDetailScreen(
              collectionId: collectionId,
              collectionEmoji: icon,
              collectionName: name,
              collectionVisibility: collectionData['isPublic'],
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
              // Display the emoji icon
              Text(
                icon,
                style: TextStyle(fontSize: 40),
              ),
              SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              SizedBox(height: 4),
              Text(
                '${recipes.length} recipes',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Create New Collection Card
  Widget _buildCreateCollectionCard(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        // Show dialog to create new collection
        showCreateCollectionDialog(context);
      },
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
                'Create New',
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
        SizedBox(height: 20),
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: // Recipes Section Title
              Text(
            isCurrentUser
                ? 'My Recipes'
                : '${userData['display_name']}\'s Recipes',
            style: theme.textTheme.titleLarge,
          ),
        ),
        SizedBox(height: 10),
        // Fetch and display user's recipes
        Container(
          margin: const EdgeInsets.only(left: 8),
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
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching recipes'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        final recipes = snapshot.data!.docs;

        if (recipes.isEmpty) {
          return Center(child: Text('You have not added any recipes yet.'));
        }

        // Prepare the list of recipe data
        List<Map<String, dynamic>> recipeDataList = recipes.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['recipeId'] = doc.id; // Add recipeId to the data
          return data;
        }).toList();

        if (recipes.length > 5) {
          recipeDataList = recipeDataList.sublist(0, 5);
        }

        // Add "View All" card if more than 5 recipes
        if (recipes.length > 5) {
          // Add "View All" card
          recipeDataList.add({
            'isViewAll': true,
            'userId': userId,
            'displayName': userData['display_name'],
            'isCurrentUser': isCurrentUser,
          });
        }

        return HorizontalRecipeRow(recipes: recipeDataList);
      },
    );
  }
}
