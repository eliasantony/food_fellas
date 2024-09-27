import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/src/utils/dialog_utils.dart';
import '../widgets/recipeCard.dart';

class CollectionDetailScreen extends StatelessWidget {
  final String collectionId;
  final String collectionEmoji;
  final String collectionName;
  final bool collectionVisibility;

  CollectionDetailScreen(
      {required this.collectionId,
      required this.collectionEmoji,
      required this.collectionName,
      required this.collectionVisibility});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$collectionEmoji   $collectionName'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              showCreateCollectionDialog(
                context,
                initialName: collectionName,
                initialIcon: collectionEmoji,
                initialVisibility: collectionVisibility,
                collectionId: collectionId,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('collections')
            .doc(collectionId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error fetching collection'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Collection not found'));
          }
          final collectionData = snapshot.data!.data() as Map<String, dynamic>;
          List<dynamic> recipeIds = collectionData['recipes'] ?? [];

          if (recipeIds.isEmpty) {
            return Center(child: Text('No recipes in this collection.'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('recipes')
                .where(FieldPath.documentId, whereIn: recipeIds)
                .snapshots(),
            builder: (context, recipeSnapshot) {
              if (recipeSnapshot.hasError) {
                return Center(child: Text('Error fetching recipes'));
              }
              if (recipeSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              final recipes = recipeSnapshot.data!.docs;

              return ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipeData =
                      recipes[index].data() as Map<String, dynamic>;
                  return RecipeCard(
                    recipeId: recipes[index].id,
                    title: recipeData['title'] ?? 'Unnamed Recipe',
                    description: recipeData['description'] ?? '',
                    rating: recipeData['averageRating']?.toDouble() ?? 0.0,
                    cookTime: recipeData['cookingTime'] ?? '',
                    thumbnailUrl: recipeData['imageUrl'] ?? '',
                    author: recipeData['author'] ?? '',
                    big: true,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
