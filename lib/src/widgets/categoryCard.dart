import 'package:flutter/material.dart';
import '../views/searchResults_screen.dart'; // Import your searchResults_screen

class CategoryCard extends StatelessWidget {
  final String title;
  final IconData iconData;
  final List<Color> gradientColors;

  const CategoryCard({
    Key? key,
    required this.title,
    required this.iconData,
    required this.gradientColors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Wrap your widget with GestureDetector
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  SearchResultsScreen()), // Navigate to SearchResultsScreen when tapped
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(
                  iconData,
                  color: Colors.white.withOpacity(0.5),
                  size: 48,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
