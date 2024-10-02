import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:food_fellas/src/utils/dialog_utils.dart';
import 'package:food_fellas/src/views/collectionDetail_screen.dart';
import 'package:food_fellas/src/widgets/hoprizontalRecipeRow.dart';
import 'package:path/path.dart';
import '../widgets/recipeCard.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Handle unauthenticated user
      return Scaffold(
        body: Center(
          child: Text('User not logged in'),
        ),
      );
    }

    final DocumentReference userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    return FutureBuilder<DocumentSnapshot>(
      future: userDoc.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading spinner while waiting for data
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          // Handle errors
          return Scaffold(
            body: Center(child: Text('Error fetching user data')),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          // Data retrieved successfully
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          return _buildProfileScreen(context, theme, userData);
        } else {
          // No data available
          return Scaffold(
            body: Center(child: Text('No user data found')),
          );
        }
      },
    );
  }

  Widget _buildProfileScreen(
      BuildContext context, ThemeData theme, Map<String, dynamic> userData) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: theme.textTheme.titleLarge),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
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
        ],
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
            // Collections Section
            _buildCollectionsSection(context, theme, userData),
            // Recipes Section
            _buildRecipesSection(context, theme, userData),
            // Badges Section
            _buildBadgesSection(context, theme),
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
      child: Column(
        children: <Widget>[
          CircleAvatar(
            backgroundImage: NetworkImage(photoUrl),
            radius: 80,
            backgroundColor: Colors.transparent,
          ),
          Text(
            displayName,
            style: theme.textTheme.headlineSmall,
          ),
          SizedBox(height: 8),
          Text(
            shortDescription,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAverageRatingSection(ThemeData theme, String userId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('recipes')
          .where('authorId', isEqualTo: userId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SizedBox(); // No recipes, so no average rating
        }

        double totalRating = 0.0;
        int totalReviews = 0;

        for (var doc in snapshot.data!.docs) {
          // Assume each recipe has an averageRating field
          double recipeRating;
          int recipeReviews;
          try {
            recipeRating = doc['averageRating']?.toDouble() ?? 0.0;
          } catch (e) {
            recipeRating = 0.0;
          }

          try {
            recipeReviews = doc['ratingsCount'] ?? 0;
          } catch (e) {
            recipeReviews = 0;
          }
          totalRating += recipeRating * recipeReviews;
          totalReviews += recipeReviews;
        }

        double averageRating =
            totalReviews > 0 ? totalRating / totalReviews : 0.0;

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

        // Assume you have a 'followers' collection under each user
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

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _ProfileStatistic(title: 'Recipes', value: '$recipesCount'),
                  _ProfileStatistic(
                      title: 'Followers', value: '$followersCount'),
                  // Add more statistics as needed
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBadgesSection(BuildContext context, ThemeData theme) {
    // Placeholder badges
    List<String> badges = ['Chef', 'Contributor', 'Foodie'];

    return Column(
      children: [
        SizedBox(height: 20),
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'My Badges:',
            style: theme.textTheme.titleLarge,
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            itemBuilder: (context, index) {
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(badges[index]),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCollectionsSection(
      BuildContext context, ThemeData theme, Map<String, dynamic> userData) {
    String userId = userData['uid'] ?? FirebaseAuth.instance.currentUser!.uid;

    return Column(
      children: [
        SizedBox(height: 20),
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'My Collections',
            style: theme.textTheme.titleLarge,
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: 170,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('collections')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error fetching collections'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                // No collections yet
                return ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCreateCollectionCard(context, theme),
                  ],
                );
              }
              final collections = snapshot.data!.docs;

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount:
                    collections.length + 1, // Extra item for "Create New"
                itemBuilder: (context, index) {
                  if (index == collections.length) {
                    // "Create New" card
                    return _buildCreateCollectionCard(context, theme);
                  } else {
                    final collectionData =
                        collections[index].data() as Map<String, dynamic>;
                    return _buildCollectionCard(
                        context, theme, collections[index].id, collectionData);
                  }
                },
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

  Widget _ProfileStatistic({required String title, required String value}) {
    return Column(
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
          child: Text(
            'My Recipes',
            style: theme.textTheme.titleLarge,
          ),
        ),
        SizedBox(height: 10),
        // Fetch and display user's recipes
        _buildUserRecipesRow(context, theme, userData),
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

        print(recipeDataList);
        return HorizontalRecipeRow(recipes: recipeDataList);
      },
    );
  }
}
