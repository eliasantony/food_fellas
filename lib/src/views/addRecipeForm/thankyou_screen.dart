import 'package:flutter/material.dart';
import 'package:food_fellas/providers/bottomNavBarProvider.dart';
import 'package:food_fellas/src/widgets/recipeCard.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class ThankYouScreen extends StatelessWidget {
  final String recipeId;

  ThankYouScreen({required this.recipeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Lottie animation in the background
          Positioned.fill(
            child: ClipRect(
              child: Lottie.asset(
                'lib/assets/lottie/confetti.json',
                repeat: false,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Your existing layout goes here
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Text(
                    'Thank you for adding a recipe!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 20),
                Center(
                  child: Text(
                    'Your recipe has been successfully\n added to our database.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 20),
                RecipeCard(recipeId: recipeId),
                SizedBox(height: 40),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Provider.of<BottomNavBarProvider>(context,
                                  listen: false)
                              .setIndex(0);
                          Navigator.of(context).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
                        ),
                        child: Text(
                          'Back to Home',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                        ),
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
