import 'package:flutter/material.dart';
import '../models/ingredient.dart';

class IngredientCard extends StatelessWidget {
  final String imageUrl;
  final double baseAmount;
  final String unit;
  final String ingredientName;
  final int servings;

  const IngredientCard({
    Key? key,
    required this.imageUrl,
    required this.baseAmount,
    required this.unit,
    required this.ingredientName,
    required this.servings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double totalAmount =
        baseAmount * servings; // Calculate total amount based on servings

    return Container(
      width: 100,
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          ClipOval(
            child: Image.asset(
              imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${totalAmount.toStringAsFixed(0)} $unit', // Display the total amount
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            ingredientName,
            style: TextStyle(
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
