class Ingredient {
  String imageUrl;
  double baseAmount;
  String unit;
  String ingredientName;
  int servings;

  Ingredient({
    required this.imageUrl,
    required this.baseAmount,
    required this.unit,
    required this.ingredientName,
    required this.servings,
  });

  String toJson() {
    return '''
    {
      "imageUrl": "$imageUrl",
      "baseAmount": $baseAmount,
      "unit": "$unit",
      "ingredientName": "$ingredientName",
      "servings": $servings
    }
    ''';
  }
}
