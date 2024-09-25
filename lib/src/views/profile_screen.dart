import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
            // Statistics Section
            _buildStatisticsSection(theme, userData),
            // Recipes Section
            _buildRecipesSection(context, theme, userData),
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
        children: <Widget>[
          CircleAvatar(
            backgroundImage: NetworkImage(photoUrl),
            radius: 40,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  style: theme.textTheme.titleLarge,
                ),
                SizedBox(height: 4),
                Text(
                  shortDescription,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: theme.iconTheme.color),
            onPressed: () {
              // Navigate to edit profile screen
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(
      ThemeData theme, Map<String, dynamic> userData) {
    // We'll fetch the recipes and calculate statistics later
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('recipes')
          .where('authorId', isEqualTo: userData['uid'])
          .get(),
      builder: (context, snapshot) {
        int recipesCount = 0;
        int totalLikes = 0;
        if (snapshot.hasData && snapshot.data != null) {
          recipesCount = snapshot.data!.docs.length;
          // Sum up the likes from each recipe
          totalLikes = snapshot.data!.docs.fold(0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            return sum + (data['likes'] as int? ?? 0);
          });
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _ProfileStatistic(title: 'Recipes', value: '$recipesCount'),
              _ProfileStatistic(title: 'Likes', value: '$totalLikes'),
              // You can add more statistics here
            ],
          ),
        );
      },
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
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 10),
        // Fetch and display user's recipes
        _buildUserRecipesList(context, theme, userData),
      ],
    );
  }

  Widget _buildUserRecipesList(
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

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipeData = recipes[index].data() as Map<String, dynamic>;
            return RecipeCard(
              recipeId: recipes[index].id,
              title: recipeData['title'] ?? 'Unnamed Recipe',
              description: recipeData['description'] ?? '',
              rating: recipeData['rating']?.toDouble() ?? 0.0,
              cookTime: recipeData['cookingTime'] ?? '',
              thumbnailUrl: recipeData['imageUrl'] ?? '',
              author: userData['display_name'] ?? '',
              big: true,
            );
          },
        );
      },
    );
  }
}