import 'package:flutter/material.dart';

class IngredientCard extends StatelessWidget {
  // final String? imageUrl;
  final double baseAmount;
  final String unit;
  final String ingredientName;
  final int servings;
  final int initialServings;

  const IngredientCard({
    Key? key,
    // required this.imageUrl,
    required this.baseAmount,
    required this.unit,
    required this.ingredientName,
    required this.servings,
    required this.initialServings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double totalAmount = baseAmount * servings / initialServings;

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
            child: _buildIngredientImage(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${totalAmount.toStringAsFixed(1)} $unit',
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
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientImage() {
      return _placeholderImage();
  }

  Widget _placeholderImage() {
    return Image.network(
      'https://placehold.co/80',
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder:
          (BuildContext context, Object exception, StackTrace? stackTrace) {
        return Container(
          width: 80,
          height: 80,
          color: Colors.grey,
          child: Icon(Icons.error, color: Colors.red),
        );
      },
    );
  }
}
